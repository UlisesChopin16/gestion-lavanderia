import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_history.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_servicio.dart';
import 'package:gestion_lavanderia/models/tables/precios/precios_conceptos.dart';

/// Cada renglón de ropa de una orden, ligado al concepto de precio que lo
/// originó. No tiene fecha de actualización ni baja lógica.
///
/// La entrega se expresa con tres columnas que siempre se escriben juntas:
/// [estaEntregado] dice si ya salió —y por lo tanto cuántos faltan—,
/// [fechaEntregado] cuándo, y [ordenHistoryId] en qué movimiento del historial
/// ocurrió.
@DataClassName('ItemServicioOrdenEntry')
@TableIndex(name: 'idx_item_orden', columns: {#ordenId})
@TableIndex(name: 'idx_item_precio_concepto', columns: {#precioConceptoId})
@TableIndex(name: 'idx_item_history', columns: {#ordenHistoryId})
class ItemServicioOrden extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId => integer().references(OrdenServicio, #id)();
  IntColumn get precioConceptoId =>
      integer().references(PreciosConceptos, #id)();
  RealColumn get cantidad => real()();
  RealColumn get importe => real()();
  BoolColumn get estaEntregado =>
      boolean().withDefault(const Constant(false))();

  /// Fecha comprometida de entrega.
  DateTimeColumn get fechaEntrega => dateTime()();

  /// Fecha en que el item se entregó realmente; null mientras no se entregue.
  DateTimeColumn get fechaEntregado => dateTime().nullable()();

  /// Movimiento del historial en el que se entregó este item; null mientras no
  /// se entregue.
  ///
  /// Es lo que permite reconstruir qué ropa se entregó en cada momento: el
  /// historial no guarda una copia de los items, los items dicen a qué
  /// movimiento pertenecen. Un item se entrega una sola vez, así que basta una
  /// columna aquí y no hace falta una tabla intermedia.
  IntColumn get ordenHistoryId =>
      integer().nullable().references(OrdenHistory, #id)();
  DateTimeColumn get fechaCreacion => dateTime()();
}
