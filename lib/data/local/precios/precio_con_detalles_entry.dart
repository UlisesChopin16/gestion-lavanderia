import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';

/// Un concepto de precio junto con la categoría a la que pertenece.
class PrecioConDetallesEntry {
  final PreciosConceptosEntry precio;
  final CategoriaServicioEntry categoria;

  const PrecioConDetallesEntry(this.precio, this.categoria);

  /// Lee la fila de un join `precios_conceptos` + `categoria_servicio`.
  ///
  /// Vive aquí para que los DAOs que necesitan este par (precios y los items de
  /// una orden) compartan la misma lectura en lugar de repetirla.
  factory PrecioConDetallesEntry.fromRow(TypedResult row, AppDatabase db) {
    return PrecioConDetallesEntry(
      row.readTable(db.preciosConceptos),
      row.readTable(db.categoriaServicio),
    );
  }
}
