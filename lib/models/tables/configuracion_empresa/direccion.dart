import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/configuracion_empresa/configuracion_empresa.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';

/// Dirección de la empresa. Se consulta por [empresaId], no por su propio id.
@DataClassName('DireccionEntry')
@TableIndex(name: 'idx_direccion_empresa', columns: {#empresaId})
class Direccion extends Table with TimestampColumns, SoftDeleteColumn {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get empresaId => integer().references(ConfiguracionEmpresa, #id)();
  TextColumn get calle => text()();
  TextColumn get numeroExterior => text()();
  TextColumn get numeroInterior => text().nullable()();
  TextColumn get colonia => text()();
  IntColumn get codigoPostal => integer()();
  TextColumn get ciudad => text()();
  TextColumn get estado => text()();
}
