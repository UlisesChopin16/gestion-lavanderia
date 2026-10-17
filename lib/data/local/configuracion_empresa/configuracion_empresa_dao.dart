import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/tables/configuracion_empresa/configuracion_empresa.dart';

part 'configuracion_empresa_dao.g.dart';

/// Configuración de la empresa: un solo registro, que la aplicación lee con
/// `id = 1`.
@DriftAccessor(tables: [ConfiguracionEmpresa])
class ConfiguracionEmpresaDao extends DatabaseAccessor<AppDatabase>
    with _$ConfiguracionEmpresaDaoMixin {
  ConfiguracionEmpresaDao(super.db);

  Future<ConfiguracionEmpresaEntry?> getById(int id) {
    final query = select(configuracionEmpresa)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> insertConfig(ConfiguracionEmpresaCompanion row) {
    return into(configuracionEmpresa).insert(
      row.copyWith(
        fechaCreacion: Value(DateTime.now()),
        fechaActualizacion: const Value(null),
      ),
    );
  }

  /// Recibe la fila concreta y no un `Insertable`: una firma que acepte
  /// cualquier `Insertable` obliga a castear a `ConfiguracionEmpresaEntry`, y
  /// ese casteo revienta en tiempo de ejecución si le llega un companion.
  Future<bool> updateConfig(ConfiguracionEmpresaEntry row) {
    return update(
      configuracionEmpresa,
    ).replace(row.copyWith(fechaActualizacion: Value(DateTime.now())));
  }
}
