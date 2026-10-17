import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';

/// Un solo registro, que la aplicación lee con `id = 1`. La dirección está en
/// su propia tabla.
@DataClassName('ConfiguracionEmpresaEntry')
class ConfiguracionEmpresa extends Table
    with TimestampColumns, SoftDeleteColumn {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text()();
  TextColumn get correo => text()();
  TextColumn get paginaWeb => text()();

  /// Ruta en disco de la imagen del logo.
  TextColumn get logo => text().nullable()();
  IntColumn get color => integer()();

  /// Contraseña para el acceso administrativo.
  TextColumn get password => text()();
}
