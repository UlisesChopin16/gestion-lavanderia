import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
export 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';
export 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
export 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
export 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart'
    show sinCategoria;
export 'package:gestion_lavanderia/models/data/shared/filas.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

part 'orden_dialog_view_model.freezed.dart';
part 'orden_dialog_view_model.g.dart';

/// Con qué quedó registrada una orden nueva: su id, para abrirla, y su folio,
/// para nombrarla.
typedef OrdenCreada = ({int id, String folio});

@freezed
sealed class OrdenDialogState with _$OrdenDialogState {
  const OrdenDialogState._();

  const factory OrdenDialogState({
    /// El catálogo del que se eligen las prendas: los conceptos vigentes.
    @Default(Filas<PrecioData>()) Filas<PrecioData> conceptos,
    @Default(Filas<CategoriaData>()) Filas<CategoriaData> categorias,

    /// Con qué se está acotando el catálogo.
    @Default('') String busquedaConcepto,
    @Default(sinCategoria) int categoriaId,

    /// Lo que se escribió para buscar al cliente, y lo que devolvió la base.
    @Default('') String busquedaCliente,
    @Default(Filas<ClienteData>()) Filas<ClienteData> encontrados,

    /// El cliente de la orden. En `null` todavía no se ha elegido.
    ClienteData? cliente,

    /// La ropa que lleva la orden, en el orden en que se fue agregando.
    @Default(Filas<ItemOrdenData>()) Filas<ItemOrdenData> items,
    @Default(MetodoPagoType.efectivo) MetodoPagoType metodoPago,

    /// Lo que el cliente paga al dejar la ropa.
    @Default(0.0) double abono,

    /// Con cuánto paga el adelanto cuando lo paga en efectivo: da quinientos
    /// para dejar trescientos. Se guarda en el primer movimiento de la orden.
    @Default(0.0) double recibido,
    @Default('') String descripcion,
    @Default(true) bool cargando,
    @Default(false) bool guardando,
    @Default('') String mensajeError,
  }) = _OrdenDialogState;

  /// Los conceptos que quedan tras el buscador y la categoría.
  ///
  /// Se filtra en memoria y no volviendo a consultar: el catálogo entra entero
  /// en una lectura y así la lista responde a cada tecla sin ir a la base.
  List<PrecioData> get conceptosVisibles {
    final texto = busquedaConcepto.trim().toLowerCase();

    return conceptos.where((concepto) {
      if (categoriaId != sinCategoria && concepto.categoriaId != categoriaId) {
        return false;
      }
      if (texto.isEmpty) return true;

      return concepto.descripcion.toLowerCase().contains(texto) ||
          concepto.categoria.toLowerCase().contains(texto);
    }).toList();
  }

  /// Cuántas unidades de un concepto lleva ya la orden. `0` si no lleva
  /// ninguna, que es lo que distingue un concepto por agregar de uno agregado.
  double cantidadDe(PrecioData concepto) {
    for (final item in items) {
      if (item.precio.id == concepto.id) return item.cantidad;
    }

    return 0;
  }

  double get total => items.fold(
    0,
    (suma, item) => suma + item.precio.importePor(item.cantidad),
  );

  /// Lo que queda a deber. Nunca negativo: el abono no pasa del total.
  double get resta => total - abono;

  /// Cuándo estaría lista la orden entera: la prenda que más tarda manda.
  DateTime? get entregaEstimada {
    DateTime? ultima;

    for (final item in items) {
      if (ultima == null || item.fechaEntrega.isAfter(ultima)) {
        ultima = item.fechaEntrega;
      }
    }

    return ultima;
  }

  /// Las cuentas del adelanto cuando se paga en efectivo.
  CobroEnEfectivo get efectivo =>
      CobroEnEfectivo(metodoPago: metodoPago, abono: abono, recibido: recibido);

  /// Una orden necesita cliente y al menos una prenda. Lo demás tiene valor de
  /// omisión: sin abono queda en curso, que es el caso normal. Lo único que la
  /// detiene es un billete que no alcanza para el adelanto que se deja.
  bool get puedeGuardar =>
      cliente != null &&
      items.isNotEmpty &&
      !efectivo.insuficiente &&
      !guardando;
}

/// El alta de una orden: a quién es, qué ropa trae y cuánto se cobra de
/// entrada.
///
/// Arma la orden completa en memoria y la escribe de una sola vez al final con
/// `crearOrden`, que es una transacción: hasta que no se confirma, no hay nada
/// a medias en la base.
///
/// Se descarta al cerrar el diálogo —el proveedor es de los que se desechan
/// solos—, así que cada alta empieza en blanco sin que nadie tenga que
/// limpiarla.
@riverpod
class OrdenDialogViewModel extends _$OrdenDialogViewModel {
  final _ordenes = instance<OrdenesLocalDatasource>();
  final _precios = instance<PreciosLocalDatasource>();
  final _categorias = instance<CategoriasLocalDatasource>();
  final _clientes = instance<ClientesLocalDatasource>();

  @override
  OrdenDialogState build() {
    Future.microtask(cargar);

    return const OrdenDialogState();
  }

  /// Lee el catálogo con el que se arma la orden.
  ///
  /// Sólo los conceptos vigentes: uno dado de baja ya no se puede cobrar, y
  /// ofrecerlo aquí sería dejar entrar a la orden algo que el catálogo retiró.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final conceptos = await _precios.activos();
      final categorias = await _categorias.todas();
      // Los recientes, para que el buscador de clientes tenga qué ofrecer en
      // cuanto se toque, antes de escribir nada.
      final recientes = await _clientes.recientes();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        conceptos: Filas(conceptos),
        categorias: Filas(categorias),
        encontrados: Filas(recientes),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo leer el catálogo de conceptos.');
    }
  }

  void buscarConcepto(String texto) {
    state = state.copyWith(busquedaConcepto: texto);
  }

  void filtrarCategoria(int categoriaId) {
    state = state.copyWith(categoriaId: categoriaId);
  }

  /// Busca al cliente por nombre, teléfono o correo.
  ///
  /// Con el buscador vacío no se listan todos —la lista está para reconocer a
  /// uno, no para hojear el catálogo—, sino los recientes: los que dejaron
  /// una orden hace poco, que son los que más probablemente vuelven.
  Future<void> buscarCliente(String texto) async {
    state = state.copyWith(busquedaCliente: texto, mensajeError: '');

    try {
      final encontrados = texto.trim().isEmpty
          ? await _clientes.recientes()
          : await _clientes.buscar(texto);

      if (!ref.mounted) return;

      state = state.copyWith(encontrados: Filas(encontrados));
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo buscar al cliente.');
    }
  }

  void elegirCliente(ClienteData cliente) {
    state = state.copyWith(cliente: cliente);
  }

  /// Vuelve al buscador para elegir a otro.
  void quitarCliente() {
    state = state.copyWith(cliente: null);
  }

  /// Repite la búsqueda después de dar de alta a alguien y lo elige si es el
  /// único que aparece.
  ///
  /// Es lo que hace que registrar a un cliente desde aquí no obligue a
  /// buscarlo otra vez: se acaba de capturar con el dato que se tecleó, así
  /// que casi siempre es el único que responde a esa búsqueda.
  ///
  /// Sin nada escrito no se elige a nadie: la lista es la de recientes, y que
  /// tenga uno solo no dice que sea el que se acaba de registrar.
  Future<void> repetirBusquedaDeCliente() async {
    await buscarCliente(state.busquedaCliente);

    if (state.busquedaCliente.trim().isEmpty) return;

    final encontrados = state.encontrados;
    if (encontrados.length == 1) elegirCliente(encontrados.first);
  }

  /// Agrega una prenda a la orden, o una más si el concepto ya estaba.
  ///
  /// Repetir el concepto suma cantidad en lugar de abrir otro renglón: dos
  /// renglones del mismo concepto con la misma fecha son el mismo renglón, y
  /// agregar tres sábanas son tres toques sobre lo mismo.
  void agregar(PrecioData concepto) {
    final items = state.items.toList();
    final indice = items.indexWhere((item) => item.precio.id == concepto.id);

    if (indice >= 0) {
      final item = items[indice];
      items[indice] = _conCantidad(item, item.cantidad + 1);
    } else {
      items.add(
        ItemOrdenData(
          precio: concepto,
          cantidad: 1,
          importe: concepto.importePor(1),
          fechaEntrega: _entregaDe(concepto),
        ),
      );
    }

    _conItems(items);
  }

  /// Cambia la cantidad de un renglón. Por debajo de una unidad el renglón se
  /// quita: una prenda de cero no es una prenda.
  void cambiarCantidad(int indice, double cantidad) {
    final items = state.items.toList();

    if (cantidad < 1) {
      items.removeAt(indice);
    } else {
      items[indice] = _conCantidad(items[indice], cantidad);
    }

    _conItems(items);
  }

  void quitar(int indice) {
    final items = state.items.toList()..removeAt(indice);

    _conItems(items);
  }

  /// Mueve la fecha prometida de un renglón.
  ///
  /// Sale calculada de los días que pide el concepto, pero se puede correr: lo
  /// que el cliente necesita para una fecha concreta manda sobre la norma.
  void cambiarEntrega(int indice, DateTime fecha) {
    final items = state.items.toList();
    items[indice] = items[indice].copyWith(fechaEntrega: fecha);

    _conItems(items);
  }

  /// El efectivo recibido sólo existe en efectivo: con tarjeta no hay cambio
  /// que sacar, y un número de antes se quedaría bloqueando el botón.
  void elegirMetodoPago(MetodoPagoType metodoPago) {
    state = state.copyWith(
      metodoPago: metodoPago,
      recibido: metodoPago == MetodoPagoType.efectivo ? state.recibido : 0,
    );
  }

  void cambiarRecibido(double recibido) {
    state = state.copyWith(recibido: recibido < 0 ? 0 : recibido);
  }

  /// Lo que se cobra al dejar la ropa, acotado entre nada y el total: cobrar
  /// de más dejaría la orden con saldo a favor, que no es algo que la base
  /// sepa representar.
  void cambiarAbono(double abono) {
    state = state.copyWith(abono: abono.clamp(0, state.total));
  }

  /// El atajo de "paga todo": el caso más común después de no abonar nada.
  void abonarTodo() => cambiarAbono(state.total);

  void cambiarDescripcion(String descripcion) {
    state = state.copyWith(descripcion: descripcion);
  }

  /// Escribe la orden. Devuelve con qué id y qué folio quedó registrada, o
  /// `null` si no se pudo guardar.
  ///
  /// Se devuelven los dos y no un `true` porque el listado necesita ambos: el
  /// folio para confirmar el alta por su nombre —el `AAMM-NNNN` lo pone la
  /// base al insertar, y es el número que el cliente se lleva—, y el id para
  /// abrir enseguida el ticket de la orden.
  Future<OrdenCreada?> guardar() async {
    final cliente = state.cliente;
    if (cliente == null || state.items.isEmpty) return null;

    state = state.copyWith(guardando: true, mensajeError: '');

    try {
      final orden = await _ordenes.crearOrden(
        clienteId: cliente.id,
        items: state.items.toList(),
        descripcion: state.descripcion.trim().isEmpty
            ? null
            : state.descripcion.trim(),
        abono: state.abono,
        metodoPago: state.metodoPago,
        recibido: state.efectivo.aGuardar,
      );

      final creada = (id: orden.id, folio: orden.folio);

      if (!ref.mounted) return creada;

      state = state.copyWith(guardando: false);

      return creada;
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo crear la orden.');

      return null;
    }
  }

  /// La ropa recién cambiada, con el abono recortado al total nuevo: quitar
  /// prendas después de haber abonado dejaba un abono mayor que la orden.
  void _conItems(List<ItemOrdenData> items) {
    state = state.copyWith(items: Filas(items));
    state = state.copyWith(abono: state.abono.clamp(0, state.total));
  }

  ItemOrdenData _conCantidad(ItemOrdenData item, double cantidad) {
    return item.copyWith(
      cantidad: cantidad,
      importe: item.precio.importePor(cantidad),
    );
  }

  /// Cuándo estaría lista una prenda: hoy más los días que pide su concepto.
  /// Se guarda a medianoche porque lo que se promete es el día, no la hora.
  DateTime _entregaDe(PrecioData concepto) {
    final hoy = DateTime.now();

    return DateTime(hoy.year, hoy.month, hoy.day + concepto.diasEntrega);
  }

  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    final detalle = error is SQLException ? error.message : mensaje;

    state = state.copyWith(
      cargando: false,
      guardando: false,
      mensajeError: detalle,
    );
  }
}
