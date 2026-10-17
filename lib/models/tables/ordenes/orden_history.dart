import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_servicio.dart';
import 'package:gestion_lavanderia/models/tables/shared/enum_converters.dart';

/// Bitácora de pagos de una orden. El índice compuesto cubre la consulta del
/// último movimiento por orden, que es la que alimenta la lista de órdenes.
@DataClassName('OrdenHistoryEntry')
@TableIndex(name: 'idx_history_orden_fecha', columns: {#ordenId, #fecha})
class OrdenHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId => integer().references(OrdenServicio, #id)();

  /// Importe de este movimiento.
  RealColumn get monto => real()();

  /// Saldo pendiente de la orden después de este movimiento.
  RealColumn get restante => real()();

  /// "Efectivo", "Tarjeta", "Transferencia", etc. El converter la entrega ya
  /// como `MetodoPagoType`.
  TextColumn get metodoPago => text().map(const MetodoPagoConverter())();
  DateTimeColumn get fecha => dateTime()();
}
