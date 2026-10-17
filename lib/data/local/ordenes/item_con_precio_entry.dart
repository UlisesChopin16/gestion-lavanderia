import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/precios/precio_con_detalles_entry.dart';

/// Un item de una orden junto con el concepto de precio que lo originó.
class ItemConPrecioEntry {
  final ItemServicioOrdenEntry item;
  final PrecioConDetallesEntry precio;

  const ItemConPrecioEntry(this.item, this.precio);

  factory ItemConPrecioEntry.fromRow(TypedResult row, AppDatabase db) {
    return ItemConPrecioEntry(
      row.readTable(db.itemServicioOrden),
      PrecioConDetallesEntry.fromRow(row, db),
    );
  }
}
