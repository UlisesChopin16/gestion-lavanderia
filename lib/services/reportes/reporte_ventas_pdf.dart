import 'dart:typed_data';

import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/services/fuentes_pdf.dart';
import 'package:gestion_lavanderia/services/logo_pdf.dart';
import 'package:gestion_lavanderia/services/reportes/partes_reporte_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// El reporte general de ventas en PDF: sale siempre, sea cual sea el
/// periodo, y se lee o se imprime tal cual.
///
/// Carta vertical: las seis columnas caben, y es la hoja que hay en
/// cualquier impresora de oficina. La tabla se parte entre páginas
/// repitiendo su encabezado; después van el resumen y el detalle de pagos.
class ReporteVentasPdf {
  const ReporteVentasPdf();

  Future<Uint8List> generar(
    ReporteVentas reporte, {
    EmpresaData? empresa,
  }) async {
    final documento = pw.Document(
      title: 'Reporte general de ventas',
      author: empresa?.nombre,
      theme: await FuentesPdf.tema(),
    );
    final logo = await LogoPdf.de(empresa);
    final pagos = reporte.pagos;

    documento.addPage(
      pw.MultiPage(
        pageFormat: hojaReporte,
        header: (context) => EncabezadoReporte(
          titulo: 'Reporte general de ventas',
          periodo:
              'Del ${reporte.rango.desde.formatDate} '
              'al ${reporte.rango.hasta.formatDate}',
          generado: reporte.generado,
          empresa: empresa,
          logo: logo,
        ),
        footer: (context) =>
            PieReporte(pagina: context.pageNumber, paginas: context.pagesCount),
        build: (context) => [
          if (reporte.ventas.isEmpty)
            VacioReporte('No se recibieron órdenes en este periodo.')
          else
            _TablaVentas(ventas: reporte.ventas),
          pw.SizedBox(height: 18),
          _Resumen(reporte: reporte),
          pw.SizedBox(height: 22),
          SeccionReporte('Detalle de pagos'),
          if (pagos.isEmpty)
            VacioReporte('Sin pagos en el periodo.')
          else ...[
            _TablaPagos(pagos: pagos),
            pw.SizedBox(height: 6),
            DestacadoReporte('Total', reporte.cobrado.enPesos),
          ],
        ],
      ),
    );

    return documento.save();
  }
}

/// Una orden por renglón.
class _TablaVentas extends pw.StatelessWidget {
  _TablaVentas({required this.ventas});

  final List<VentaReporte> ventas;

  @override
  pw.Widget build(pw.Context context) {
    return TablaReporte(
      columnas: ReporteVentas.columnas,
      filas: [
        for (final venta in ventas)
          [
            venta.folio,
            venta.total.enPesos,
            venta.pagado.enPesos,
            venta.estado.titulo,
            venta.saldo.enPesos,
            venta.fechaPago?.formatFullDate ?? '—',
          ],
      ],
      alineaciones: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
      anchos: const [1.1, 1, 1, 0.9, 1.1, 1.4],
    );
  }
}

/// Un cobro por renglón, por folio como la tabla de órdenes: de aquí salen lo
/// cobrado y lo cobrado por método del resumen.
class _TablaPagos extends pw.StatelessWidget {
  _TablaPagos({required this.pagos});

  final List<PagoReporte> pagos;

  @override
  pw.Widget build(pw.Context context) {
    return TablaReporte(
      columnas: ReporteVentas.columnasPagos,
      filas: [
        for (final pago in pagos)
          [
            pago.folio,
            pago.fecha.formatFullDate,
            pago.metodo.value,
            pago.monto.enPesos,
          ],
      ],
      alineaciones: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      anchos: const [1, 1.3, 1, 1],
    );
  }
}

/// Lo que suman las órdenes: el total cobrado, lo cobrado contra lo
/// pendiente y lo cobrado por método de pago.
class _Resumen extends pw.StatelessWidget {
  _Resumen({required this.reporte});

  final ReporteVentas reporte;

  @override
  pw.Widget build(pw.Context context) {
    final vendido = reporte.totalVendido;
    final cobrado = reporte.cobrado;
    final porMetodo = reporte.cobradoPorMetodo;
    final ordenes = reporte.ventas.length - reporte.canceladas;
    final canceladas = reporte.canceladas;

    return RecuadroReporte(
      children: [
        TituloResumen('Resumen'),
        RenglonResumen(
          'Órdenes',
          '$ordenes${canceladas == 0 ? '' : ' (y $canceladas cancelada'
                    '${canceladas == 1 ? '' : 's'}, que no cuentan)'}',
        ),
        RenglonResumen('Total vendido', vendido.enPesos),
        pw.SizedBox(height: 4),
        DestacadoReporte('Total cobrado', cobrado.enPesos),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  TituloResumen('Cobrado vs. pendiente'),
                  RenglonResumen(
                    'Cobrado',
                    cobrado.enPesos,
                    porcentaje: RenglonResumen.porcentajeDe(cobrado, vendido),
                  ),
                  RenglonResumen(
                    'Pendiente',
                    reporte.pendiente.enPesos,
                    porcentaje: RenglonResumen.porcentajeDe(
                      reporte.pendiente,
                      vendido,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  TituloResumen('Cobrado por método de pago'),
                  if (porMetodo.isEmpty)
                    VacioReporte('Sin cobros en el periodo')
                  else
                    for (final MapEntry(key: metodo, value: importe)
                        in porMetodo.entries)
                      RenglonResumen(
                        metodo.value,
                        importe.enPesos,
                        porcentaje: RenglonResumen.porcentajeDe(
                          importe,
                          cobrado,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
