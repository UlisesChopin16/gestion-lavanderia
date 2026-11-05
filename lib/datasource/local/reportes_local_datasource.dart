import 'package:collection/collection.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_servicio_orden_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_servicio_dao.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/models/data/reportes/cuentas_por_cobrar.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/models/data/reportes/ropa_pendiente.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';

export 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
export 'package:gestion_lavanderia/models/data/reportes/cuentas_por_cobrar.dart';
export 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
export 'package:gestion_lavanderia/models/data/reportes/ropa_pendiente.dart';

/// Los datos de los reportes, ya armados como modelos.
///
/// Sólo lee: un reporte es una foto de lo que hay en la base.
class ReportesLocalDatasource {
  const ReportesLocalDatasource(this._ordenes, this._history, this._items);

  final OrdenServicioDao _ordenes;
  final OrdenHistoryDao _history;
  final ItemServicioOrdenDao _items;

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

  /// El corte de caja del [dia] —lo que se cobró, de cualquier orden— y lo
  /// cobrado en los días anteriores, para compararlo.
  ///
  /// Es una sola consulta por los siete días: el corte sale de los cobros del
  /// último, y la comparación de sumar los de cada uno.
  Future<EstadisticasCorte> estadisticasCorte(
    DateTime dia, {
    DateTime? ahora,
  }) async {
    final hasta = RangoReporte(dia, dia).desde;
    final desde = DateTime(
      hasta.year,
      hasta.month,
      hasta.day - (EstadisticasCorte.dias - 1),
    );
    final rango = RangoReporte(desde, hasta);

    final cobros = [
      for (final (:movimiento, :folio, :cliente) in await _history.cobrosEntre(
        rango.inicio,
        rango.fin,
      ))
        CobroCorte(
          folio: folio,
          cliente: cliente,
          fecha: movimiento.fecha,
          metodo: movimiento.metodoPago,
          monto: movimiento.monto,
          recibido: movimiento.recibido,
        ),
    ];
    final porDia = groupBy(cobros, (cobro) => cobro.fecha.soloDia);
    final dias = [
      for (var i = 0; i < EstadisticasCorte.dias; i++)
        DateTime(desde.year, desde.month, desde.day + i),
    ];

    return EstadisticasCorte(
      corte: CorteCaja(
        dia: hasta,
        generado: ahora ?? DateTime.now(),
        cobros: porDia[hasta] ?? const [],
      ),
      semana: [
        for (final dia in dias)
          (
            dia: dia,
            total: (porDia[dia] ?? const <CobroCorte>[])
                .map((cobro) => cobro.monto)
                .sum,
          ),
      ],
    );
  }

  /// Las órdenes que deben algo, con el cliente al que hay que llamar.
  Future<CuentasPorCobrar> cuentasPorCobrar({DateTime? ahora}) async {
    return CuentasPorCobrar(
      hoy: (ahora ?? DateTime.now()).soloDia,
      saldos: [
        for (final (:orden, :cliente) in await _ordenes.conSaldo())
          SaldoPendiente(
            folio: orden.folio,
            clienteId: cliente.id,
            cliente: _nombre(cliente),
            telefono: cliente.telefono,
            recibida: orden.fechaCreacion,
            total: orden.total,
            saldo: orden.restante,
          ),
      ],
    );
  }

  /// La ropa que falta por entregar, junta por orden.
  Future<RopaPendiente> ropaPendiente({DateTime? ahora}) async {
    final porOrden = groupBy(
      await _items.pendientesDeEntrega(),
      (pendiente) => pendiente.orden.id,
    );

    return RopaPendiente(
      hoy: (ahora ?? DateTime.now()).soloDia,
      ordenes: [
        for (final pendientes in porOrden.values)
          OrdenConRopaPendiente(
            folio: pendientes.first.orden.folio,
            cliente: _nombre(pendientes.first.cliente),
            telefono: pendientes.first.cliente.telefono,
            saldo: pendientes.first.orden.restante,
            conceptos: [
              for (final (:item, orden: _, cliente: _) in pendientes)
                ConceptoPendiente(
                  nombre: item.precio.precio.nombreConcepto,
                  cantidad: item.item.cantidad,
                  unidad: item.precio.precio.tipoUnidad,
                  prometida: item.item.fechaEntrega,
                ),
            ],
          ),
      ],
    );
  }

  static String _nombre(ClienteEntry cliente) =>
      '${cliente.nombres} ${cliente.apellidos}'.trim();

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
