import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
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

  /// Escribe sobre la configuración [id] las columnas que traiga [row]; las que
  /// vengan ausentes se quedan como están.
  ///
  /// Recibe el companion y el id por separado en lugar de la fila completa: la
  /// pantalla de configuración edita unos pocos campos y así no tiene que
  /// acarrear la contraseña ni las fechas de auditoría para guardar un teléfono.
  Future<void> updateConfig({
    required int id,
    required ConfiguracionEmpresaCompanion row,
  }) async {
    final statement = update(configuracionEmpresa)
      ..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'La configuración que se intentó actualizar ya no existe.',
    );
  }
}
