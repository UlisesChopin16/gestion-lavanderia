import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_servicio.dart';
import 'package:gestion_lavanderia/models/tables/precios/precios_conceptos.dart';

/// Cada renglón de ropa de una orden, ligado al concepto de precio que lo
/// originó. No tiene fecha de actualización ni baja lógica.
@DataClassName('ItemServicioOrdenEntry')
@TableIndex(name: 'idx_item_orden', columns: {#ordenId})
@TableIndex(name: 'idx_item_precio_concepto', columns: {#precioConceptoId})
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
  DateTimeColumn get fechaCreacion => dateTime()();
}
