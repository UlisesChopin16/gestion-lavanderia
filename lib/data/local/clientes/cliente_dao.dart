import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/shared/query_ordering.dart';
import 'package:gestion_lavanderia/data/local/shared/text_search.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
import 'package:gestion_lavanderia/models/tables/clientes/cliente.dart';

part 'cliente_dao.g.dart';

@DriftAccessor(tables: [Cliente])
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

  Future<bool> updateCliente(ClienteEntry row) async {
    await _ensureContactoUnico(
      correo: row.correo,
      telefono: row.telefono,
      excluyendoId: row.id,
    );

    return update(
      cliente,
    ).replace(row.copyWith(fechaActualizacion: Value(DateTime.now())));
  }

  /// Dos clientes no pueden compartir correo ni teléfono.
  ///
  /// La comparación es insensible a mayúsculas en ambos casos (alta y edición):
  /// si el alta respetara mayúsculas, `Ana@x.com` podría darse de alta dos
  /// veces y luego fallar al editarla.
  Future<void> _ensureContactoUnico({
    required String correo,
    required String telefono,
    int? excluyendoId,
  }) async {
    final query = selectOnly(cliente)
      ..addColumns([cliente.id])
      ..where(
        cliente.correo.lower().equals(correo.toLowerCase()) |
            cliente.telefono.lower().equals(telefono.toLowerCase()),
      )
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
