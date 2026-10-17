import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_con_precio_entry.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
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

    return _toItems(await query.get());
  }

  /// Los items de la orden que ya se entregaron, cada uno con el movimiento del
  /// historial al que pertenece su entrega.
  Future<List<ItemConPrecioEntry>> getEntregadosByOrden(int ordenId) async {
    final query = _queryJoined()
      ..where(
        itemServicioOrden.ordenId.equals(ordenId) &
            itemServicioOrden.ordenHistoryId.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(itemServicioOrden.id)]);

    return _toItems(await query.get());
  }

  /// Cuántos items de la orden faltan por entregar.
  Future<int> contarPendientes(int ordenId) async {
    final cuenta = itemServicioOrden.id.count();
    final query = selectOnly(itemServicioOrden)
      ..addColumns([cuenta])
      ..where(
        itemServicioOrden.ordenId.equals(ordenId) &
            itemServicioOrden.estaEntregado.equals(false),
      );

    return (await query.getSingle()).read(cuenta) ?? 0;
  }

  /// Marca como entregados los items indicados y los liga al movimiento del
  /// historial en el que se entregaron. Devuelve cuántos se entregaron.
  ///
  /// Las tres columnas de la entrega se escriben en una sola sentencia para que
  /// no puedan quedar desalineadas: `estaEntregado` —de donde sale cuántos
  /// faltan—, `fechaEntregado` y `ordenHistoryId`.
  ///
  /// Los items que ya estaban entregados quedan fuera: su entrega pertenece al
  /// movimiento en el que ocurrió, y volver a marcarlos la movería de lugar.
  /// Hay que llamarla dentro de la transacción que registra el movimiento, con
  /// su `id` y su misma fecha.
  ///
  /// La condición incluye [ordenId] y no sólo los ids: sin él, un id de otra
  /// orden se marcaría como entregado y quedaría colgado de un movimiento que no
  /// es suyo.
  Future<int> entregarItems({
    required int ordenId,
    required Iterable<int> itemIds,
    required int ordenHistoryId,
    required DateTime fecha,
  }) {
    if (itemIds.isEmpty) return Future.value(0);

    final statement = update(itemServicioOrden)
      ..where(
        (t) =>
            t.ordenId.equals(ordenId) &
            t.id.isIn(itemIds) &
            t.estaEntregado.equals(false),
      );

    return statement.write(
      ItemServicioOrdenCompanion(
        estaEntregado: const Value(true),
        fechaEntregado: Value(fecha),
        ordenHistoryId: Value(ordenHistoryId),
      ),
    );
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

  /// Escribe sobre el item [id] las columnas que traiga [row]; las que vengan
  /// ausentes se quedan como están.
  Future<void> updateItem({
    required int id,
    required ItemServicioOrdenCompanion row,
  }) async {
    final statement = update(itemServicioOrden)..where((t) => t.id.equals(id));
    final escritas = await statement.write(_paraActualizar(row));

    if (escritas > 0) return;

    throw const SQLException(
      message: 'El item que se intentó actualizar ya no existe.',
    );
  }

  /// Actualiza varios items en una sola operación, cada uno con las columnas
  /// que traiga su companion: un `UPDATE` por item, pero un solo viaje a la
  /// base en lugar de uno por renglón de la orden.
  Future<void> updateItems(Map<int, ItemServicioOrdenCompanion> cambios) {
    if (cambios.isEmpty) return Future.value();

    return batch((b) {
      for (final cambio in cambios.entries) {
        b.update(
          itemServicioOrden,
          _paraActualizar(cambio.value),
          where: (t) => t.id.equals(cambio.key),
        );
      }
    });
  }

  /// El id y la fecha de creación se descartan: son las dos columnas que una
  /// actualización nunca debe tocar.
  ItemServicioOrdenCompanion _paraActualizar(ItemServicioOrdenCompanion row) {
    return row.copyWith(
      id: const Value.absent(),
      fechaCreacion: const Value.absent(),
    );
  }

  List<ItemConPrecioEntry> _toItems(List<TypedResult> rows) {
    return rows
        .map((row) => ItemConPrecioEntry.fromRow(row, attachedDatabase))
        .toList();
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
