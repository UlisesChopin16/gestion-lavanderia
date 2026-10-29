import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/shared/query_ordering.dart';
import 'package:gestion_lavanderia/data/local/shared/text_search.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
import 'package:gestion_lavanderia/models/tables/clientes/cliente.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_servicio.dart';

part 'cliente_dao.g.dart';

@DriftAccessor(tables: [Cliente, OrdenServicio])
class ClientesDao extends DatabaseAccessor<AppDatabase>
    with _$ClientesDaoMixin {
  ClientesDao(super.db);

  Map<ColumnClientesName, Expression<Object>> get _columnasOrdenables => {
    ColumnClientesName.id: cliente.id,
    ColumnClientesName.nombre: cliente.nombres,
    ColumnClientesName.apellido: cliente.apellidos,
    ColumnClientesName.telefono: cliente.telefono,
    ColumnClientesName.correo: cliente.correo,
    ColumnClientesName.fechaCreacion: cliente.fechaCreacion,
  };

  /// Columnas sobre las que busca el cuadro de búsqueda de clientes.
  List<Expression<String>> get _columnasBusqueda => [
    cliente.nombres,
    cliente.apellidos,
    cliente.correo,
    cliente.telefono,
  ];

  Future<List<ClienteEntry>> getAll() {
    final query = select(cliente)
      ..orderBy([
        (t) => OrderingTerm.asc(t.nombres),
        (t) => OrderingTerm.asc(t.apellidos),
      ]);

    return query.get();
  }

  /// Listado de la pantalla de clientes, con los filtros ya aplicados.
  Future<List<ClienteEntry>> listado(FiltrosClientes filtros) {
    final query = select(cliente);

    if (filtros.nombre.isNotEmpty) {
      query.where((_) => likeAllWords(filtros.nombre, _columnasBusqueda));
    }

    query.orderByTerms(
      buildOrdering(
        ordenamiento: filtros.ordenamiento,
        columnas: _columnasOrdenables,
        ascendente: filtros.ascendente,
        desempate: cliente.id,
      ),
    );

    return query.get();
  }

  Future<ClienteEntry?> getById(int id) {
    return (select(cliente)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<ClienteEntry>> getClientesByInfo(String info) {
    final query = select(cliente)
      ..where((_) => likeAllWords(info, _columnasBusqueda))
      ..orderBy([(t) => OrderingTerm.asc(t.nombres)]);

    return query.get();
  }

  /// Los [limite] clientes más a mano: primero los que dejaron una orden más
  /// recientemente, y después —los que nunca han dejado una— los registrados
  /// más recientemente.
  ///
  /// Es lo que se ofrece al abrir el buscador del alta antes de escribir: en
  /// el mostrador, el cliente de hoy suele ser el de la semana pasada.
  Future<List<ClienteEntry>> getRecientes(int limite) {
    final ultimaOrden = ordenServicio.fechaCreacion.max();
    final query =
        select(cliente).join([
            leftOuterJoin(
              ordenServicio,
              ordenServicio.clienteId.equalsExp(cliente.id),
            ),
          ])
          ..groupBy([cliente.id])
          ..orderBy([
            OrderingTerm(
              expression: ultimaOrden,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.desc(cliente.fechaCreacion),
            // Las fechas se guardan al segundo: dos altas seguidas empatan, y
            // el id más alto es el registro más nuevo.
            OrderingTerm.desc(cliente.id),
          ])
          ..limit(limite);

    return query.map((fila) => fila.readTable(cliente)).get();
  }

  Future<int> insertCliente(ClienteCompanion row) async {
    await _ensureContactoUnico(
      correo: row.correo.value,
      telefono: row.telefono.value,
    );

    return into(cliente).insert(
      row.copyWith(
        fechaCreacion: Value(DateTime.now()),
        fechaActualizacion: const Value(null),
      ),
    );
  }

  /// Escribe sobre el cliente [id] las columnas que traiga [row]; las que
  /// vengan ausentes se quedan como están.
  ///
  /// El duplicado se busca contra la fila *como quedará*: lo que el companion
  /// no manda se toma de la fila actual, porque editar sólo el teléfono debe
  /// comparar el correo que el cliente ya tenía y no una cadena vacía.
  Future<void> updateCliente({
    required int id,
    required ClienteCompanion row,
  }) async {
    final actual = await _filaActual(id);

    await _ensureContactoUnico(
      correo: row.correo.present ? row.correo.value : actual.correo,
      telefono: row.telefono.present ? row.telefono.value : actual.telefono,
      excluyendoId: id,
    );

    final statement = update(cliente)..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'El cliente que se intentó actualizar ya no existe.',
    );
  }

  Future<ClienteEntry> _filaActual(int id) async {
    final fila = await getById(id);
    if (fila != null) return fila;

    throw const SQLException(
      message: 'El cliente que se intentó actualizar ya no existe.',
    );
  }

  /// Dos clientes no pueden compartir correo ni teléfono.
  ///
  /// La comparación es insensible a mayúsculas en ambos casos (alta y edición):
  /// si el alta respetara mayúsculas, `Ana@x.com` podría darse de alta dos
  /// veces y luego fallar al editarla.
  ///
  /// Un dato vacío no se compara. El correo es opcional —un cliente de
  /// mostrador muchas veces sólo deja su teléfono—, y comparándolo tal cual el
  /// segundo cliente sin correo chocaba con el primero: los dos tienen la
  /// cadena vacía y la consulta los daba por el mismo.
  Future<void> _ensureContactoUnico({
    required String correo,
    required String telefono,
    int? excluyendoId,
  }) async {
    final iguales = [
      if (correo.trim().isNotEmpty)
        cliente.correo.lower().equals(correo.toLowerCase()),
      if (telefono.trim().isNotEmpty)
        cliente.telefono.lower().equals(telefono.toLowerCase()),
    ];

    if (iguales.isEmpty) return;

    final query = selectOnly(cliente)
      ..addColumns([cliente.id])
      ..where(iguales.reduce((a, b) => a | b))
      ..limit(1);

    if (excluyendoId != null) {
      query.where(cliente.id.equals(excluyendoId).not());
    }

    if (await query.getSingleOrNull() == null) return;

    throw const SQLException(
      message: 'Ya hay un cliente en la base de datos con los mismos datos.',
    );
  }
}
