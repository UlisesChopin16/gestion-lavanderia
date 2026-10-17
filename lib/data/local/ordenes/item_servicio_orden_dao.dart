import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_con_precio_entry.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/item_servicio_orden.dart';

export 'package:gestion_lavanderia/data/local/ordenes/item_con_precio_entry.dart';

part 'item_servicio_orden_dao.g.dart';

/// Los items de una orden. Se insertan y actualizan por lotes, dentro de la
/// transacción de la orden.
@DriftAccessor(tables: [ItemServicioOrden])
class ItemServicioOrdenDao extends DatabaseAccessor<AppDatabase>
    with _$ItemServicioOrdenDaoMixin {
  ItemServicioOrdenDao(super.db);

  Future<List<ItemConPrecioEntry>> getItemsByOrden(int ordenId) async {
    final query = _queryJoined()
      ..where(itemServicioOrden.ordenId.equals(ordenId))
      ..orderBy([OrderingTerm.asc(itemServicioOrden.id)]);

    return (await query.get())
        .map((row) => ItemConPrecioEntry.fromRow(row, attachedDatabase))
        .toList();
  }

  Future<int> insertItem(ItemServicioOrdenCompanion row) {
    return into(
      itemServicioOrden,
    ).insert(row.copyWith(fechaCreacion: Value(DateTime.now())));
  }

  /// Inserta todos los items de una orden en una sola operación, en lugar de un
  /// `INSERT` por item.
  Future<void> insertItems(Iterable<ItemServicioOrdenCompanion> rows) {
    if (rows.isEmpty) return Future.value();

    final now = DateTime.now();
    return batch((b) {
      b.insertAll(
        itemServicioOrden,
        rows.map((row) => row.copyWith(fechaCreacion: Value(now))).toList(),
      );
    });
  }

  Future<bool> updateItem(ItemServicioOrdenEntry row) {
    return update(itemServicioOrden).replace(row);
  }

  /// Actualiza todos los items de una orden en una sola operación.
  Future<void> updateItems(Iterable<ItemServicioOrdenEntry> rows) {
    if (rows.isEmpty) return Future.value();

    return batch((b) => b.replaceAll(itemServicioOrden, rows.toList()));
  }

  JoinedSelectStatement _queryJoined() {
    return select(itemServicioOrden).join([
      innerJoin(
        preciosConceptos,
        preciosConceptos.id.equalsExp(itemServicioOrden.precioConceptoId),
      ),
      innerJoin(
        categoriaServicio,
        categoriaServicio.id.equalsExp(preciosConceptos.categoriaId),
      ),
    ]);
  }
}
