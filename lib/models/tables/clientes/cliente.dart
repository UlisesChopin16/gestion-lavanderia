import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';

/// Los índices cubren la búsqueda de duplicados al crear o editar un cliente
/// (`correo` / `telefono`), que son comparaciones por igualdad.
@DataClassName('ClienteEntry')
@TableIndex(name: 'idx_cliente_correo', columns: {#correo})
@TableIndex(name: 'idx_cliente_telefono', columns: {#telefono})
class Cliente extends Table with TimestampColumns, SoftDeleteColumn {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombres => text()();
  TextColumn get apellidos => text()();
  TextColumn get correo => text()();
  TextColumn get telefono => text()();
}
