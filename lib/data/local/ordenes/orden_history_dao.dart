import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_con_detalles_entry.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/shared/query_ordering.dart';
import 'package:gestion_lavanderia/data/local/shared/text_search.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_history.dart';

export 'package:gestion_lavanderia/data/local/ordenes/orden_con_detalles_entry.dart';

part 'orden_history_dao.g.dart';

/// Bitácora de pagos de las órdenes.
///
/// Es además la fuente de la lista de órdenes, porque cada renglón muestra la
/// orden junto con su movimiento de pago más reciente.
@DriftAccessor(tables: [OrdenHistory])
class OrdenHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$OrdenHistoryDaoMixin {
  OrdenHistoryDao(super.db);

  Map<ColumnsOrdenesNames, Expression<Object>> get _columnasOrdenables => {
    ColumnsOrdenesNames.id: ordenServicio.id,
    ColumnsOrdenesNames.folio: ordenServicio.folio,
    ColumnsOrdenesNames.cliente: cliente.nombres,
    ColumnsOrdenesNames.estatus: ordenServicio.estatus,
    ColumnsOrdenesNames.total: ordenServicio.total,
    ColumnsOrdenesNames.restante: ordenServicio.restante,
    ColumnsOrdenesNames.metodoPago: ordenHistory.metodoPago,
    ColumnsOrdenesNames.fechaCreacion: ordenServicio.fechaCreacion,
    ColumnsOrdenesNames.ultimaInteraccion: ordenHistory.fecha,
    ColumnsOrdenesNames.fechaCierre: ordenServicio.fechaCierre,
  };

  /// Listado de la pantalla de órdenes, con los filtros ya aplicados.
  Future<List<OrdenConDetallesEntry>> listado(FiltrosOrdenes filtros) async {
    return _toDetalles(await _queryFiltrado(filtros).get());
  }

  Future<List<OrdenHistoryEntry>> getHistoryByOrden(int ordenId) {
    final query = select(ordenHistory)
      ..where((t) => t.ordenId.equals(ordenId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.fecha),
        (t) => OrderingTerm.desc(t.id),
      ]);

    return query.get();
  }

  /// El último movimiento de una orden, localizado por el `id` más alto y no
  /// por la fecha: dos movimientos pueden compartir el mismo instante.
  ///
  /// Es el movimiento que se actualiza cuando se guarda una orden sin abono, en
  /// lugar de duplicarlo.
  Future<OrdenHistoryEntry?> getLastByOrden(int ordenId) {
    final query = select(ordenHistory)
      ..where((t) => t.ordenId.equals(ordenId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<int> insertHistory(OrdenHistoryCompanion row) {
    return into(ordenHistory).insert(row);
  }

  /// Escribe sobre el movimiento [id] las columnas que traiga [row].
  ///
  /// Es lo que se usa al guardar una orden sin abono: el último movimiento se
  /// corrige en lugar de duplicarse.
  Future<void> updateHistory({
    required int id,
    required OrdenHistoryCompanion row,
  }) async {
    final statement = update(ordenHistory)..where((t) => t.id.equals(id));
    final escritas = await statement.write(
      row.copyWith(id: const Value.absent()),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'El movimiento que se intentó actualizar ya no existe.',
    );
  }

  /// Órdenes con su cliente y su último movimiento de pago.
  ///
  /// El movimiento se localiza por el id más alto de la orden. Unirlo por
  /// `ordenHistory.fecha == ordenServicio.fechaActualizacion` sería un join por
  /// igualdad de instantes: bastaría un milisegundo de diferencia entre ambas
  /// columnas para que la orden desapareciera por completo de la lista.
  JoinedSelectStatement _queryJoined() {
    final movimiento = alias(ordenHistory, 'ultimo_movimiento');

    final idUltimoMovimiento = subqueryExpression<int>(
      selectOnly(movimiento)
        ..addColumns([movimiento.id.max()])
        ..where(movimiento.ordenId.equalsExp(ordenServicio.id)),
    );

    return select(ordenServicio).join([
      innerJoin(ordenHistory, ordenHistory.id.equalsExp(idUltimoMovimiento)),
      innerJoin(cliente, cliente.id.equalsExp(ordenServicio.clienteId)),
    ]);
  }

  JoinedSelectStatement _queryFiltrado(FiltrosOrdenes filtros) {
    final query = _queryJoined();

    if (filtros.estatus != EstatusOrdenType.todos) {
      query.where(ordenServicio.estatus.equalsValue(filtros.estatus));
    }

    if (filtros.busqueda.isNotEmpty) {
      query.where(
        likeAllWords(filtros.busqueda, [
          cliente.nombres,
          cliente.apellidos,
          ordenServicio.folio,
        ]),
      );
    }

    final metodoPago = filtros.metodoPago;
    if (metodoPago != null) {
      query.where(ordenHistory.metodoPago.equalsValue(metodoPago));
    }

    final rango = _rangoFechas(filtros.fechaInicio, filtros.fechaFin);
    if (rango != null) query.where(rango);

    query.orderBy(
      buildOrdering(
        ordenamiento: filtros.ordenamiento,
        columnas: _columnasOrdenables,
        ascendente: filtros.ascendente,
        desempate: ordenServicio.id,
      ),
    );

    return query;
  }

  /// Traduce el rango elegido en el calendario a una condición sobre la fecha
  /// de creación. El rango puede venir completo, abierto por un extremo, o
  /// vacío.
  Expression<bool>? _rangoFechas(DateTime? inicio, DateTime? fin) {
    final finDelDia = fin?.finDelDia;

    if (inicio != null && finDelDia != null) {
      return ordenServicio.fechaCreacion.isBetweenValues(inicio, finDelDia);
    }
    if (inicio != null) {
      return ordenServicio.fechaCreacion.isBiggerOrEqualValue(inicio);
    }
    if (finDelDia != null) {
      return ordenServicio.fechaCreacion.isSmallerOrEqualValue(finDelDia);
    }
    return null;
  }

  List<OrdenConDetallesEntry> _toDetalles(List<TypedResult> rows) {
    return rows
        .map((row) => OrdenConDetallesEntry.fromRow(row, attachedDatabase))
        .toList();
  }
}

extension on DateTime {
  /// Último instante del día, para que el filtro incluya la fecha final
  /// completa y no sólo su medianoche.
  DateTime get finDelDia => DateTime(year, month, day, 23, 59, 59, 999);
}
