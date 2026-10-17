import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/history_con_items_entry.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_servicio_orden_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_data_mapper.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_servicio_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_listado_data.dart';

export 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
export 'package:gestion_lavanderia/models/data/ordenes/orden_listado_data.dart';

/// Las órdenes: su listado, su detalle y las escrituras que las mueven.
///
/// Es donde la fila se vuelve modelo y donde viven las operaciones atómicas del
/// módulo. Una orden toca cuatro tablas —orden, ropa, historial y cliente— y
/// ningún DAO puede coordinar a otro, así que toda escritura que involucre a más
/// de una pasa por aquí envuelta en una transacción.
///
/// Lo que sale son [OrdenListadoData] y [OrdenDetalleData]: la lista aplanada
/// para los renglones y el detalle con la ropa y el historial anidados. Las
/// filas de drift no salen de esta capa.
class OrdenesLocalDatasource {
  const OrdenesLocalDatasource(
    this._db,
    this._ordenes,
    this._history,
    this._items,
    this._clientes,
    this._store,
  );

  final AppDatabase _db;
  final OrdenServicioDao _ordenes;
  final OrdenHistoryDao _history;
  final ItemServicioOrdenDao _items;
  final ClientesDao _clientes;
  final FiltrosStore _store;

  /// Los importes son `double`, así que un saldo que debería ser cero puede
  /// quedar en 0.0000001 después de varias restas. Medio centavo es el margen
  /// con el que una orden se considera saldada.
  static const _margenSaldo = 0.005;

  FiltrosOrdenes get filtros => _store.ordenes;

  /// Listado de la pantalla de órdenes. Vive en [OrdenHistoryDao] porque cada
  /// renglón muestra la orden junto con su último movimiento de pago.
  Future<List<OrdenListadoData>> listado() async {
    return (await _history.listado(_store.ordenes)).toData();
  }

  Future<List<OrdenListadoData>> aplicarFiltros(FiltrosOrdenes filtros) async {
    await _store.guardarOrdenes(filtros);
    return (await _history.listado(filtros)).toData();
  }

  /// La orden completa: sus datos, su cliente, su ropa y su historial.
  Future<OrdenDetalleData?> detalle(int ordenId) async {
    final orden = await _ordenes.getById(ordenId);
    if (orden == null) return null;

    return _detalleDe(orden);
  }

  /// El historial de una orden: cada movimiento con la ropa que se entregó en
  /// él, del más reciente al más antiguo.
  Future<List<MovimientoData>> historial(int ordenId) async {
    return (await _historialDe(ordenId)).toData();
  }

  /// Cuántos items de la orden faltan por entregar.
  Future<int> pendientesPorEntregar(int ordenId) =>
      _items.contarPendientes(ordenId);

  /// Crea la orden con su ropa y su primer movimiento.
  ///
  /// Tres tablas en una transacción, y el orden no es casual: la orden primero,
  /// porque su id es lo que la ropa y el movimiento necesitan, y su folio se
  /// genera dentro de la misma transacción para que dos órdenes creadas a la vez
  /// no reciban el mismo número.
  ///
  /// Sin la transacción, un fallo a mitad deja una orden sin ropa, o con ropa y
  /// sin movimiento; y como el listado une cada orden con su último movimiento,
  /// una orden sin movimiento no aparecería en ninguna pantalla.
  ///
  /// El primer movimiento se registra aunque no haya abono: es el que fecha el
  /// alta de la orden y el que la hace visible en el listado.
  ///
  /// Es `async` aunque el cuerpo ya devuelva un `Future`: así las validaciones
  /// de arriba fallan como un `Future` rechazado y no de forma sincrónica, que
  /// se escaparía del `catch` de quien la llama.
  Future<OrdenDetalleData> crearOrden({
    required int clienteId,
    required List<ItemOrdenData> items,
    String? descripcion,
    double abono = 0,
    MetodoPagoType metodoPago = MetodoPagoType.efectivo,
  }) async {
    if (items.isEmpty) {
      throw const SQLException(
        message: 'Una orden necesita al menos una prenda.',
      );
    }

    final renglones = items.map(_conImporte).toList();
    final total = _importeDe(renglones);
    final restante = _saldo(total - _abonoValido(abono, total));

    return _db.transaction(() async {
      final orden = await _ordenes.insertOrden(
        OrdenServicioCompanion.insert(
          clienteId: clienteId,
          folio: '',
          descripcion: Value(descripcion),
          estatus: _estatusTras(restante: restante, todoEntregado: false),
          total: total,
          restante: restante,
          fechaCreacion: DateTime.now(),
        ),
      );

      await _items.insertItems(
        renglones.map((item) => item.toCompanion(ordenId: orden.id)),
      );

      // Comparte la fecha de la orden a propósito: el alta y su primer
      // movimiento son el mismo hecho.
      await _history.insertHistory(
        OrdenHistoryCompanion.insert(
          ordenId: orden.id,
          monto: abono,
          restante: restante,
          metodoPago: metodoPago,
          fecha: orden.fechaCreacion,
        ),
      );

      return _detalleDe(orden);
    });
  }

  /// Registra un movimiento de la orden: lo que se abona y la ropa que sale
  /// con ese abono.
  ///
  /// Es la operación atómica central del módulo, y los pasos van en este orden
  /// porque cada uno depende del anterior: se inserta el movimiento, se ligan
  /// los items entregados a su id —`entregarItems` escribe las tres columnas de
  /// la entrega juntas y con la misma fecha— y al final se recalculan el saldo y
  /// el estatus de la orden, que dependen de cuánta ropa quedó pendiente.
  ///
  /// Partirlo dejaría la orden cobrada sin la ropa entregada, o la ropa fuera
  /// sin un movimiento que la explique: el historial se reconstruye desde los
  /// items, así que un item entregado sin movimiento es una entrega que nadie
  /// puede fechar.
  ///
  /// Se puede abonar sin entregar y entregar sin abonar: ninguno de los dos
  /// argumentos es obligatorio.
  Future<OrdenDetalleData> registrarMovimiento({
    required int ordenId,
    double monto = 0,
    MetodoPagoType metodoPago = MetodoPagoType.efectivo,
    Iterable<int> itemsAEntregar = const [],
  }) {
    return _db.transaction(() async {
      final orden = await _ordenVigente(ordenId);
      final restante = _saldo(
        orden.restante - _abonoValido(monto, orden.restante),
      );
      final fecha = DateTime.now();

      final movimientoId = await _history.insertHistory(
        OrdenHistoryCompanion.insert(
          ordenId: ordenId,
          monto: monto,
          restante: restante,
          metodoPago: metodoPago,
          fecha: fecha,
        ),
      );

      await _items.entregarItems(
        ordenId: ordenId,
        itemIds: itemsAEntregar,
        ordenHistoryId: movimientoId,
        fecha: fecha,
      );

      return _detalleDe(
        await _cerrarSiProcede(
          ordenId: ordenId,
          restante: restante,
          fecha: fecha,
        ),
      );
    });
  }

  /// Agrega ropa a una orden y recalcula su total y su saldo.
  ///
  /// Atómico porque el total de la orden tiene que cuadrar con sus renglones: si
  /// los items se insertaran sin actualizar el total, la orden entregaría más de
  /// lo que cobra. Agregar ropa a una orden ya pagada la vuelve a poner en
  /// curso, porque lo nuevo todavía no está cobrado.
  Future<OrdenDetalleData> agregarItems({
    required int ordenId,
    required List<ItemOrdenData> items,
  }) async {
    if (items.isEmpty) {
      throw const SQLException(message: 'No hay prendas que agregar.');
    }

    final renglones = items.map(_conImporte).toList();
    final importe = _importeDe(renglones);

    return _db.transaction(() async {
      final orden = await _ordenVigente(ordenId);

      await _items.insertItems(
        renglones.map((item) => item.toCompanion(ordenId: ordenId)),
      );

      return _detalleDe(
        await _cerrarSiProcede(
          ordenId: ordenId,
          restante: _saldo(orden.restante + importe),
          total: orden.total + importe,
          fecha: DateTime.now(),
        ),
      );
    });
  }

  /// Escribe el saldo de la orden y el estatus que le toca.
  ///
  /// Lo comparten [registrarMovimiento] y [agregarItems] porque las dos cambian
  /// el saldo y las dos tienen que volver a decidir si la orden sigue en curso:
  /// duplicar la decisión es lo que acaba con dos pantallas cerrando órdenes con
  /// criterios distintos.
  Future<OrdenServicioEntry> _cerrarSiProcede({
    required int ordenId,
    required double restante,
    required DateTime fecha,
    double? total,
  }) async {
    final pendientes = await _items.contarPendientes(ordenId);
    final estatus = _estatusTras(
      restante: restante,
      todoEntregado: pendientes == 0,
    );
    final cerrada = estatus == EstatusOrdenType.cerrada;

    return _ordenes.updateOrden(
      id: ordenId,
      row: OrdenServicioCompanion(
        total: total == null ? const Value.absent() : Value(total),
        restante: Value(restante),
        estatus: Value(estatus),
        // Se limpia cuando la orden deja de estar cerrada: agregarle ropa la
        // reabre, y una orden en curso con fecha de cierre no se entiende.
        fechaCierre: Value(cerrada ? fecha : null),
      ),
    );
  }

  /// Cómo queda el estatus de una orden después de moverla.
  ///
  /// `pagado` cuando ya no queda saldo, `cerrada` cuando además salió toda la
  /// ropa, y `en curso` mientras falte una de las dos cosas. Es la única regla
  /// de negocio de esta clase y está en un solo lugar: si la lavandería cambia
  /// su criterio de cierre, se cambia aquí y no en cada pantalla.
  EstatusOrdenType _estatusTras({
    required double restante,
    required bool todoEntregado,
  }) {
    if (restante > _margenSaldo) return EstatusOrdenType.enCurso;

    return todoEntregado ? EstatusOrdenType.cerrada : EstatusOrdenType.pagado;
  }

  /// La orden, siempre que todavía admita movimientos.
  ///
  /// Una orden cerrada o cancelada no se mueve: cobrar sobre una cerrada
  /// reabriría una cuenta que ya cuadró.
  Future<OrdenServicioEntry> _ordenVigente(int ordenId) async {
    final orden = await _ordenes.getById(ordenId);

    if (orden == null) {
      throw const SQLException(message: 'La orden ya no existe.');
    }

    const finales = {EstatusOrdenType.cerrada, EstatusOrdenType.cancelada};
    if (!finales.contains(orden.estatus)) return orden;

    throw SQLException(
      message:
          'La orden ${orden.folio} está en estatus '
          '"${orden.estatus.value}" y ya no admite movimientos.',
    );
  }

  /// Un abono no puede ser negativo ni pasarse del saldo: cobrar de más dejaría
  /// un restante negativo que ninguna pantalla sabe mostrar.
  double _abonoValido(double monto, double tope) {
    if (monto < 0) {
      throw const SQLException(message: 'El abono no puede ser negativo.');
    }

    if (monto <= tope + _margenSaldo) return monto;

    throw SQLException(
      message:
          'El abono de ${monto.toStringAsFixed(2)} es mayor que el saldo '
          'de ${tope.toStringAsFixed(2)}.',
    );
  }

  /// Redondea a cero el saldo que sólo difiere de cero por el error de los
  /// `double`.
  double _saldo(double restante) =>
      restante.abs() < _margenSaldo ? 0 : restante;

  double _importeDe(Iterable<ItemOrdenData> items) =>
      items.fold(0.0, (suma, item) => suma + item.importe);

  /// El importe del renglón se recalcula con el precio del concepto y la
  /// cantidad, en lugar de tomarse de lo que mandó la pantalla: así el total de
  /// la orden no puede quedar desalineado de lo que cuesta su ropa.
  ItemOrdenData _conImporte(ItemOrdenData item) =>
      item.copyWith(importe: item.precio.importePor(item.cantidad));

  Future<OrdenDetalleData> _detalleDe(OrdenServicioEntry orden) async {
    final cliente = await _clientes.getById(orden.clienteId);

    if (cliente == null) {
      throw SQLException(
        message: 'La orden ${orden.folio} apunta a un cliente que no existe.',
      );
    }

    return orden.toDetalle(
      cliente: cliente,
      items: await _items.getItemsByOrden(orden.id),
      historial: await _historialDe(orden.id),
    );
  }

  /// Son dos consultas y el reparto en memoria, y no un join: unidos, cada
  /// movimiento se repetiría una vez por item entregado, y el movimiento sin
  /// entregas necesitaría un `LEFT JOIN` para no desaparecer.
  Future<List<HistoryConItemsEntry>> _historialDe(int ordenId) async {
    final movimientos = await _history.getHistoryByOrden(ordenId);
    if (movimientos.isEmpty) return const [];

    final entregados = await _items.getEntregadosByOrden(ordenId);
    final porMovimiento = entregados.groupListsBy(
      (entregado) => entregado.item.ordenHistoryId,
    );

    return movimientos
        .map(
          (movimiento) => HistoryConItemsEntry(
            movimiento: movimiento,
            entregados: porMovimiento[movimiento.id] ?? const [],
          ),
        )
        .toList();
  }
}
