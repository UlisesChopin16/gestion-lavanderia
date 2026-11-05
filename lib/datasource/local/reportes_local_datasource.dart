import 'package:collection/collection.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_servicio_dao.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';

export 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';

/// Los datos de los reportes, ya armados como modelos.
///
/// Sólo lee: un reporte es una foto de lo que hay en la base.
class ReportesLocalDatasource {
  const ReportesLocalDatasource(this._ordenes, this._history);

  final OrdenServicioDao _ordenes;
  final OrdenHistoryDao _history;

  /// Las órdenes recibidas en [rango], cada una con lo que se le ha cobrado.
  ///
  /// Son dos consultas —las órdenes y sus movimientos— que se juntan aquí: un
  /// solo `join` repetiría la orden en cada uno de sus movimientos.
  Future<ReporteVentas> ventas(RangoReporte rango, {DateTime? ahora}) async {
    final ordenes = await _ordenes.recibidasEntre(rango.inicio, rango.fin);
    final movimientos = groupBy(
      await _history.deOrdenesRecibidasEntre(rango.inicio, rango.fin),
      (movimiento) => movimiento.ordenId,
    );

    return ReporteVentas(
      rango: rango,
      generado: ahora ?? DateTime.now(),
      ventas: [
        for (final orden in ordenes)
          _venta(orden, movimientos[orden.id] ?? const []),
      ],
    );
  }

  VentaReporte _venta(
    OrdenServicioEntry orden,
    List<OrdenHistoryEntry> movimientos,
  ) {
    // El movimiento del alta existe aunque no se haya cobrado nada: sólo
    // cuentan los que traen dinero.
    final pagos = [
      for (final cobro in movimientos.sortedBy((m) => m.fecha))
        if (cobro.monto > 0)
          PagoReporte(
            folio: orden.folio,
            fecha: cobro.fecha,
            metodo: cobro.metodoPago,
            monto: cobro.monto,
          ),
    ];

    return VentaReporte(
      folio: orden.folio,
      fecha: orden.fechaCreacion,
      total: orden.total,
      cancelada: orden.estatus == EstatusOrdenType.cancelada,
      pagos: pagos,
    );
  }
}
