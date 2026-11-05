import 'dart:typed_data';

import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/services/fuentes_pdf.dart';
import 'package:gestion_lavanderia/services/logo_pdf.dart';
import 'package:gestion_lavanderia/services/reportes/partes_reporte_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// El corte de caja de un día en PDF.
///
/// Arriba lo que se cuenta al cerrar: cuánto se cobró, cuánto efectivo debe
/// haber en la caja y cuánto entró por cada método. Abajo, cada cobro, para
/// encontrar la diferencia si la cuenta no sale.
class CorteCajaPdf {
  const CorteCajaPdf();

  Future<Uint8List> generar(CorteCaja corte, {EmpresaData? empresa}) async {
    final documento = pw.Document(
      title: 'Corte de caja',
      author: empresa?.nombre,
      theme: await FuentesPdf.tema(),
    );
    final logo = await LogoPdf.de(empresa);

    documento.addPage(
      pw.MultiPage(
        pageFormat: hojaReporte,
        header: (context) => EncabezadoReporte(
          titulo: 'Corte de caja',
          periodo: _primeraMayuscula(corte.dia.formatLongDate),
          generado: corte.generado,
          empresa: empresa,
          logo: logo,
        ),
        footer: (context) =>
            PieReporte(pagina: context.pageNumber, paginas: context.pagesCount),
        build: (context) => [
          _Resumen(corte: corte),
          pw.SizedBox(height: 22),
          SeccionReporte('Detalle de cobros'),
          if (corte.cobros.isEmpty)
            VacioReporte('No se cobró nada este día.')
          else ...[
            _TablaCobros(cobros: corte.cobros),
            pw.SizedBox(height: 6),
            DestacadoReporte('Total', corte.total.enPesos),
          ],
        ],
      ),
    );

    return documento.save();
  }

  static String _primeraMayuscula(String texto) =>
      texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
}

/// Lo que se cuenta al cerrar la caja.
class _Resumen extends pw.StatelessWidget {
  _Resumen({required this.corte});

  final CorteCaja corte;

  @override
  pw.Widget build(pw.Context context) {
    final total = corte.total;
    final porMetodo = corte.porMetodo;
    final cobros = corte.cobros.length;
    final ordenes = corte.ordenes;

    return RecuadroReporte(
      children: [
        TituloResumen('Resumen'),
        RenglonResumen(
          'Cobros',
          '$cobros ${cobros == 1 ? 'cobro' : 'cobros'} en $ordenes '
              '${ordenes == 1 ? 'orden' : 'órdenes'}',
        ),
        pw.SizedBox(height: 4),
        DestacadoReporte('Total cobrado', total.enPesos),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  TituloResumen('Efectivo'),
                  RenglonResumen(
                    'Entregado por los clientes',
                    corte.efectivoRecibido.enPesos,
                  ),
                  RenglonResumen(
                    'Cambio dado',
                    '-${corte.cambioEntregado.enPesos}',
                  ),
                  pw.SizedBox(height: 4),
                  DestacadoReporte(
                    'Debe haber en caja',
                    corte.efectivoCobrado.enPesos,
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      'Más el fondo con el que se abrió la caja.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: TintaReporte.tenue,
                      ),
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
                    VacioReporte('Sin cobros este día')
                  else
                    for (final MapEntry(key: metodo, value: importe)
                        in porMetodo.entries)
                      RenglonResumen(
                        metodo.value,
                        importe.enPesos,
                        porcentaje: RenglonResumen.porcentajeDe(importe, total),
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

/// Cada cobro, por folio. En efectivo, con cuánto pagó y su cambio.
class _TablaCobros extends pw.StatelessWidget {
  _TablaCobros({required this.cobros});

  final List<CobroCorte> cobros;

  @override
  pw.Widget build(pw.Context context) {
    return TablaReporte(
      columnas: CorteCaja.columnas,
      filas: [
        for (final cobro in cobros)
          [
            cobro.folio,
            cobro.fecha.formatTime,
            cobro.cliente,
            cobro.metodo.value,
            cobro.monto.enPesos,
            cobro.entregado?.enPesos ?? '—',
            cobro.cambio?.enPesos ?? '—',
          ],
      ],
      alineaciones: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      anchos: const [1, 0.6, 1.8, 1.1, 1, 1, 0.9],
    );
  }
}
