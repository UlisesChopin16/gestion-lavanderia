import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/categorias/categoria_servicio.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';
import 'package:gestion_lavanderia/models/tables/shared/enum_converters.dart';

/// El catálogo de lo que se cobra.
///
/// `idx_precio_categoria` cubre el join con [CategoriaServicio], que ocurre en
/// toda lectura de precios. `idx_precio_unico` cubre la verificación de
/// duplicados (categoría + tamaño + concepto); **no** es un índice único,
/// porque las filas dadas de baja siguen existiendo y la unicidad se valida en
/// el DAO.
@DataClassName('PreciosConceptosEntry')
@TableIndex(name: 'idx_precio_categoria', columns: {#categoriaId})
@TableIndex(name: 'idx_precio_estatus', columns: {#estatus})
@TableIndex(
  name: 'idx_precio_unico',
  columns: {#categoriaId, #clotheSize, #nombreConcepto},
)
class PreciosConceptos extends Table with TimestampColumns, SoftDeleteColumn {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoriaId => integer().references(CategoriaServicio, #id)();

  /// Descripción de `ClotheSizeType`, ya tipada por el converter.
  TextColumn get clotheSize => text().map(const ClotheSizeConverter())();
  TextColumn get nombreConcepto => text()();

  /// Días de entrega de este concepto dentro de su categoría.
  IntColumn get diasEntrega => integer()();

  /// "Kg", "Pieza", etc. El converter la entrega ya como `UnitType`.
  TextColumn get tipoUnidad => text().map(const UnitConverter())();
  RealColumn get importe => real()();

  /// "Activo" o "Inactivo". El converter la entrega ya como `EstatusType`.
  TextColumn get estatus => text().map(const EstatusConverter())();
}
