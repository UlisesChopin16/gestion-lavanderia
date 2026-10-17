import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/tables/configuracion_empresa/direccion.dart';

part 'direccion_dao.g.dart';

@DriftAccessor(tables: [Direccion])
class DireccionDao extends DatabaseAccessor<AppDatabase>
    with _$DireccionDaoMixin {
  DireccionDao(super.db);

  Future<DireccionEntry?> getById(int id) {
    final query = select(direccion)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Dirección de una empresa.
  ///
  /// Es la consulta que realmente necesita la capa superior: pasarle el id de
  /// la *empresa* a [getById] sólo devuelve la dirección cuando ambos ids
  /// coinciden por casualidad.
  Future<DireccionEntry?> getByEmpresaId(int empresaId) {
    final query = select(direccion)
      ..where((t) => t.empresaId.equals(empresaId))
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<int> insertDireccion(DireccionCompanion row) {
    return into(direccion).insert(
      row.copyWith(
        fechaCreacion: Value(DateTime.now()),
        fechaActualizacion: const Value(null),
      ),
    );
  }

  Future<bool> updateDireccion(DireccionEntry row) {
    return update(
      direccion,
    ).replace(row.copyWith(fechaActualizacion: Value(DateTime.now())));
  }
}
