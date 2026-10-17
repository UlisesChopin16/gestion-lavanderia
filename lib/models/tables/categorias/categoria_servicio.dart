import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';
import 'package:gestion_lavanderia/models/tables/shared/enum_converters.dart';

/// Agrupa los conceptos de precio. Ej. "Ropa de cama", "Planchado".
@DataClassName('CategoriaServicioEntry')
@TableIndex(name: 'idx_categoria_estatus', columns: {#estatus})
@TableIndex(name: 'idx_categoria_nombre', columns: {#nombre})
class CategoriaServicio extends Table with TimestampColumns, SoftDeleteColumn {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();

  /// "Activo" o "Inactivo". El converter la entrega ya como `EstatusType`.
  TextColumn get estatus => text().map(const EstatusConverter())();

  /// Días de entrega por omisión para los conceptos de esta categoría.
  IntColumn get diasEntrega => integer()();
}
