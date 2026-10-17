import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
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

  /// Escribe sobre la dirección [id] las columnas que traiga [row]; las que
  /// vengan ausentes se quedan como están.
  Future<void> updateDireccion({
    required int id,
    required DireccionCompanion row,
  }) async {
    final statement = update(direccion)..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'La dirección que se intentó actualizar ya no existe.',
    );
  }
}
