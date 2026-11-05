import 'dart:typed_data';

import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/services/reportes/libro_xlsx.dart';

/// El reporte general de ventas como libro de Excel: sale junto al PDF
/// cuando se pide, para filtrar y sumar las órdenes en una hoja de cálculo.
///
/// Arriba, de quién es, de qué y de cuándo; luego la tabla, con filtro en el
/// encabezado y el encabezado fijo al desplazarse; luego el resumen, y al
/// final el detalle de pagos, del que salen lo cobrado y lo cobrado por
/// método.
class ReporteVentasExcel {
  const ReporteVentasExcel();

  Uint8List generar(ReporteVentas reporte, {EmpresaData? empresa}) {
    final nombre = empresa?.nombre ?? '';
    final direccion = empresa?.direccionImpresa ?? '';
    final contacto = (empresa?.contacto ?? const <String>[]).join('  ·  ');

    final filas = <List<CeldaXlsx?>>[
      [const TextoXlsx('Reporte general de ventas', EstiloXlsx.titulo)],
      if (nombre.isNotEmpty) [TextoXlsx(nombre, EstiloXlsx.seccion)],
      if (direccion.isNotEmpty) [TextoXlsx(direccion, EstiloXlsx.nota)],
      if (contacto.isNotEmpty) [TextoXlsx(contacto, EstiloXlsx.nota)],
      [
        TextoXlsx(
          'Del ${reporte.rango.desde.formatDate} '
          'al ${reporte.rango.hasta.formatDate}',
          EstiloXlsx.nota,
        ),
      ],
      [
        TextoXlsx(
          'Generado el ${reporte.generado.formatFullDate}',
          EstiloXlsx.nota,
        ),
      ],
      [],
    ];

    final filaEncabezado = filas.length;
    filas.add([
      for (final titulo in ReporteVentas.columnas)
        TextoXlsx(titulo, EstiloXlsx.encabezado),
    ]);

    for (final (indice, venta) in reporte.ventas.indexed) {
      EstiloXlsx estilo(EstiloXlsx base) => indice.isOdd ? base.rayado : base;
      final fechaPago = venta.fechaPago;

      filas.add([
        TextoXlsx(venta.folio, estilo(EstiloXlsx.texto)),
        NumeroXlsx(venta.total, estilo(EstiloXlsx.pesos)),
        NumeroXlsx(venta.pagado, estilo(EstiloXlsx.pesos)),
        TextoXlsx(venta.estado.titulo, estilo(EstiloXlsx.textoCentrado)),
        NumeroXlsx(venta.saldo, estilo(EstiloXlsx.pesos)),
        if (fechaPago == null)
          TextoXlsx('', estilo(EstiloXlsx.texto))
        else
          FechaXlsx(fechaPago, estilo(EstiloXlsx.fecha)),
      ]);
    }

    final filaFinal = filas.length - 1;

    filas
      ..addAll(_resumen(reporte))
      ..addAll(_detallePagos(reporte));

    return const LibroXlsx().generar(
      HojaXlsx(
        nombre: 'Ventas',
        filas: filas,
        // La segunda columna es también la fecha y hora del detalle de pagos.
        anchos: const [16, 18, 16, 14, 18, 20],
        // Sin órdenes no hay qué filtrar, y un filtro de sólo encabezado
        // confunde más de lo que ayuda.
        filtro: reporte.ventas.isEmpty
            ? null
            : RangoXlsx(
                filaInicial: filaEncabezado,
                filaFinal: filaFinal,
                columnas: ReporteVentas.columnas.length,
              ),
        filasFijas: filaEncabezado + 1,
        ajustarAlAncho: true,
      ),
    );
  }

  /// Lo que suman las órdenes, debajo de la tabla. La etiqueta en la primera
  /// columna y el importe en la del total, para que se lean a plomo.
  List<List<CeldaXlsx?>> _resumen(ReporteVentas reporte) {
    final vendido = reporte.totalVendido;
    final porMetodo = reporte.cobradoPorMetodo;

    /// [de] es aquello de lo que el importe es parte, para su porcentaje.
    List<CeldaXlsx?> renglon(
      String etiqueta,
      double importe, {
      bool total = false,
      double? de,
    }) => [
      TextoXlsx(
        etiqueta,
        total ? EstiloXlsx.etiquetaTotal : EstiloXlsx.etiqueta,
      ),
      // La etiqueta es más larga que su columna: la segunda va vacía para
      // que se lea entera, y en un total se rellena para que la banda siga.
      if (total) const TextoXlsx('', EstiloXlsx.etiquetaTotal) else null,
      NumeroXlsx(
        importe,
        total ? EstiloXlsx.pesosTotal : EstiloXlsx.pesosResumen,
      ),
      if (de != null && de > 0) NumeroXlsx(importe / de, EstiloXlsx.porcentaje),
    ];

    return [
      [],
      [const TextoXlsx('Resumen', EstiloXlsx.seccion)],
      [
        const TextoXlsx('Órdenes', EstiloXlsx.etiqueta),
        null,
        NumeroXlsx(
          (reporte.ventas.length - reporte.canceladas).toDouble(),
          EstiloXlsx.entero,
        ),
        if (reporte.canceladas > 0)
          TextoXlsx(
            'y ${reporte.canceladas} cancelada'
            '${reporte.canceladas == 1 ? '' : 's'}, que no cuentan',
            EstiloXlsx.nota,
          ),
      ],
      renglon('Total vendido', vendido),
      renglon('Total cobrado', reporte.cobrado, total: true),
      [],
      [const TextoXlsx('Cobrado vs. pendiente', EstiloXlsx.seccion)],
      renglon('Cobrado', reporte.cobrado, de: vendido),
      renglon('Pendiente', reporte.pendiente, de: vendido),
      [],
      [const TextoXlsx('Cobrado por método de pago', EstiloXlsx.seccion)],
      if (porMetodo.isEmpty)
        [const TextoXlsx('Sin cobros en el periodo', EstiloXlsx.nota)]
      else
        for (final MapEntry(key: metodo, value: importe) in porMetodo.entries)
          renglon(metodo.value, importe, de: reporte.cobrado),
    ];
  }

  /// Un renglón por cobro, rayados como la tabla de órdenes, y al final su
  /// total, que es el mismo que el total cobrado del resumen.
  List<List<CeldaXlsx?>> _detallePagos(ReporteVentas reporte) {
    final pagos = reporte.pagos;

    return [
      [],
      [const TextoXlsx('Detalle de pagos', EstiloXlsx.seccion)],
      if (pagos.isEmpty)
        [const TextoXlsx('Sin pagos en el periodo', EstiloXlsx.nota)]
      else ...[
        [
          for (final titulo in ReporteVentas.columnasPagos)
            TextoXlsx(titulo, EstiloXlsx.encabezado),
        ],
        for (final (indice, pago) in pagos.indexed)
          _pago(pago, rayado: indice.isOdd),
        [
          const TextoXlsx('Total', EstiloXlsx.etiquetaTotal),
          const TextoXlsx('', EstiloXlsx.etiquetaTotal),
          const TextoXlsx('', EstiloXlsx.etiquetaTotal),
          NumeroXlsx(reporte.cobrado, EstiloXlsx.pesosTotal),
        ],
      ],
    ];
  }

  List<CeldaXlsx?> _pago(PagoReporte pago, {required bool rayado}) {
    EstiloXlsx estilo(EstiloXlsx base) => rayado ? base.rayado : base;

    return [
      TextoXlsx(pago.folio, estilo(EstiloXlsx.texto)),
      FechaXlsx(pago.fecha, estilo(EstiloXlsx.fecha)),
      TextoXlsx(pago.metodo.value, estilo(EstiloXlsx.texto)),
      NumeroXlsx(pago.monto, estilo(EstiloXlsx.pesos)),
    ];
  }
}
