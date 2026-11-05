import 'dart:typed_data';

import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/services/fuentes_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// El reporte general de ventas en PDF: el de los periodos de hasta un mes,
/// que se lee o se imprime tal cual.
///
/// Carta vertical: las seis columnas caben, y es la hoja que hay en
/// cualquier impresora de oficina. La tabla se parte entre páginas
/// repitiendo su encabezado; después van el resumen y el detalle de pagos.
class ReporteVentasPdf {
  const ReporteVentasPdf();

  Future<Uint8List> generar(
    ReporteVentas reporte, {
    String empresa = '',
  }) async {
    final documento = pw.Document(
      title: 'Reporte general de ventas',
      author: empresa.isEmpty ? null : empresa,
      theme: await FuentesPdf.tema(),
    );

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.copyWith(
          marginLeft: 40,
          marginRight: 40,
          marginTop: 36,
          marginBottom: 36,
        ),
        header: (context) => _Encabezado(reporte: reporte, empresa: empresa),
        footer: (context) =>
            _Pie(pagina: context.pageNumber, paginas: context.pagesCount),
        build: (context) => [
          if (reporte.ventas.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Text(
                'No se recibieron órdenes en este periodo.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(color: _Tinta.tenue),
              ),
            )
          else
            _Tabla(reporte: reporte),
          pw.SizedBox(height: 18),
          _Resumen(reporte: reporte),
          pw.SizedBox(height: 22),
          _Seccion('Detalle de pagos'),
          if (reporte.pagos.isEmpty)
            pw.Text(
              'Sin pagos en el periodo.',
              style: const pw.TextStyle(fontSize: 10, color: _Tinta.tenue),
            )
          else ...[
            _TablaPagos(pagos: reporte.pagos),
            pw.SizedBox(height: 6),
            _Destacado('Total', reporte.cobrado.enPesos),
          ],
        ],
      ),
    );

    return documento.save();
  }
}

/// Una orden por renglón, rayados. Al partirse entre páginas repite el
/// encabezado.
class _Tabla extends pw.StatelessWidget {
  _Tabla({required this.reporte});

  final ReporteVentas reporte;

  @override
  pw.Widget build(pw.Context context) {
    return pw.TableHelper.fromTextArray(
      headers: ReporteVentas.columnas,
      data: [
        for (final venta in reporte.ventas)
          [
            venta.folio,
            venta.total.enPesos,
            venta.pagado.enPesos,
            venta.estado.titulo,
            venta.saldo.enPesos,
            venta.fechaPago?.formatFullDate ?? '—',
          ],
      ],
      headerCount: 1,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: _Tinta.encabezado),
      cellStyle: const pw.TextStyle(fontSize: 9),
      // El rayado: un renglón sí y uno no, como en los listados.
      oddRowDecoration: const pw.BoxDecoration(color: _Tinta.rayado),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _Tinta.linea, width: 0.5),
        ),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerAlignment: pw.Alignment.center,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(),
        2: pw.FlexColumnWidth(),
        3: pw.FlexColumnWidth(0.9),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1.4),
      },
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
    return pw.TableHelper.fromTextArray(
      headers: ReporteVentas.columnasPagos,
      data: [
        for (final pago in pagos)
          [
            pago.folio,
            pago.fecha.formatFullDate,
            pago.metodo.value,
            pago.monto.enPesos,
          ],
      ],
      headerCount: 1,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: _Tinta.encabezado),
      cellStyle: const pw.TextStyle(fontSize: 9),
      oddRowDecoration: const pw.BoxDecoration(color: _Tinta.rayado),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _Tinta.linea, width: 0.5),
        ),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerAlignment: pw.Alignment.center,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(),
        3: pw.FlexColumnWidth(),
      },
    );
  }
}

/// El título de una parte del reporte que va después del resumen.
class _Seccion extends pw.StatelessWidget {
  _Seccion(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}

/// De quién es el reporte, de qué periodo y cuándo se sacó. Se repite
/// arriba de cada página.
class _Encabezado extends pw.StatelessWidget {
  _Encabezado({required this.reporte, required this.empresa});

  final ReporteVentas reporte;
  final String empresa;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (empresa.isNotEmpty)
                  pw.Text(
                    empresa,
                    style: const pw.TextStyle(fontSize: 9, color: _Tinta.tenue),
                  ),
                pw.Text(
                  'Reporte general de ventas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Del ${reporte.rango.desde.formatDate} '
                  'al ${reporte.rango.hasta.formatDate}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.Text(
            'Generado el ${reporte.generado.formatFullDate}',
            style: const pw.TextStyle(fontSize: 8, color: _Tinta.tenue),
          ),
        ],
      ),
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

    // Entero en una página: partido, deja un recuadro vacío al pie de una
    // y sus cifras en la siguiente.
    return pw.Inseparable(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _Tinta.linea),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _Titulo('RESUMEN'),
            _Renglon(
              'Órdenes',
              '$ordenes${canceladas == 0 ? '' : ' (y $canceladas cancelada'
                        '${canceladas == 1 ? '' : 's'}, que no cuentan)'}',
            ),
            _Renglon('Total vendido', vendido.enPesos),
            pw.SizedBox(height: 4),
            _Destacado('Total cobrado', cobrado.enPesos),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _Titulo('COBRADO VS. PENDIENTE'),
                      _Renglon(
                        'Cobrado',
                        cobrado.enPesos,
                        porcentaje: _porcentaje(cobrado, vendido),
                      ),
                      _Renglon(
                        'Pendiente',
                        reporte.pendiente.enPesos,
                        porcentaje: _porcentaje(reporte.pendiente, vendido),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _Titulo('COBRADO POR MÉTODO DE PAGO'),
                      if (porMetodo.isEmpty)
                        pw.Text(
                          'Sin cobros en el periodo',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _Tinta.tenue,
                          ),
                        )
                      else
                        for (final MapEntry(key: metodo, value: importe)
                            in porMetodo.entries)
                          _Renglon(
                            metodo.value,
                            importe.enPesos,
                            porcentaje: _porcentaje(importe, cobrado),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String? _porcentaje(double parte, double de) =>
      de > 0 ? '${(parte / de * 100).toStringAsFixed(1)} %' : null;
}

class _Titulo extends pw.StatelessWidget {
  _Titulo(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 8,
          letterSpacing: 0.8,
          color: _Tinta.tenue,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}

/// Una etiqueta y su importe; a la derecha, si lleva, qué parte es.
class _Renglon extends pw.StatelessWidget {
  _Renglon(this.etiqueta, this.valor, {this.porcentaje});

  final String etiqueta;
  final String valor;
  final String? porcentaje;

  @override
  pw.Widget build(pw.Context context) {
    final porcentaje = this.porcentaje;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
          if (porcentaje != null)
            pw.SizedBox(
              width: 48,
              child: pw.Text(
                porcentaje,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 8, color: _Tinta.tenue),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un total que se tiene que ver: va sobre fondo.
class _Destacado extends pw.StatelessWidget {
  _Destacado(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  pw.Widget build(pw.Context context) {
    final estilo = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: _Tinta.destacado,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(etiqueta, style: estilo)),
          pw.Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Pie extends pw.StatelessWidget {
  _Pie({required this.pagina, required this.paginas});

  final int pagina;
  final int paginas;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página $pagina de $paginas',
        style: const pw.TextStyle(fontSize: 8, color: _Tinta.tenue),
      ),
    );
  }
}

/// Los mismos tonos que el Excel, para que los dos reportes se parezcan.
abstract final class _Tinta {
  static const encabezado = PdfColor.fromInt(0xFF1F4E78);
  static const rayado = PdfColor.fromInt(0xFFF2F2F2);
  static const destacado = PdfColor.fromInt(0xFFDDEBF7);
  static const linea = PdfColor.fromInt(0xFFD9D9D9);
  static const tenue = PdfColor.fromInt(0xFF595959);
}
