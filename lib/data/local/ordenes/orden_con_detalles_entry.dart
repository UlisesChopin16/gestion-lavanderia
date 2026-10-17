import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';

/// Una orden con su cliente y su último movimiento de pago.
class OrdenConDetallesEntry {
  final OrdenServicioEntry orden;
  final OrdenHistoryEntry detalles;
  final ClienteEntry cliente;

  const OrdenConDetallesEntry({
    required this.orden,
    required this.detalles,
    required this.cliente,
  });

  factory OrdenConDetallesEntry.fromRow(TypedResult row, AppDatabase db) {
    return OrdenConDetallesEntry(
      orden: row.readTable(db.ordenServicio),
      detalles: row.readTable(db.ordenHistory),
      cliente: row.readTable(db.cliente),
    );
  }
}
