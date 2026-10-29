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

  /// La cuenta desde la que se envían los tickets por correo: servidor SMTP,
  /// puerto y usuario. Vacíos mientras no se configure, que es lo normal: el
  /// correo es opcional.
  ///
  /// La contraseña de esa cuenta no está aquí: se guarda cifrada fuera de la
  /// base —`SecretosCorreo`—, porque `app.db` es un archivo que cualquiera
  /// con acceso al equipo puede abrir.
  TextColumn get smtpServidor => text().withDefault(const Constant(''))();
  IntColumn get smtpPuerto => integer().withDefault(const Constant(0))();
  TextColumn get smtpUsuario => text().withDefault(const Constant(''))();
}
