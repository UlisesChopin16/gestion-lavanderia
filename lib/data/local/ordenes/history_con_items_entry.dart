import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_con_precio_entry.dart';

/// Un movimiento del historial de una orden junto con la ropa que se entregó en
/// ese momento.
class HistoryConItemsEntry {
  final OrdenHistoryEntry movimiento;

  /// Los items entregados en este movimiento. Vacío si no se entregó nada:
  /// un movimiento puede ser sólo un abono.
  final List<ItemConPrecioEntry> entregados;

  const HistoryConItemsEntry({
    required this.movimiento,
    required this.entregados,
  });

  /// Lo cobrado en el movimiento no tiene por qué cubrir lo que salió: se puede
  /// entregar ropa sin abonar y abonar sin entregar.
  bool get huboEntrega => entregados.isNotEmpty;
}
