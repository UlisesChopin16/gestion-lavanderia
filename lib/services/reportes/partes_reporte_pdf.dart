import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Las piezas que comparten los reportes en PDF, para que todos se vean como
// de la misma lavandería: el encabezado con sus datos, el pie con la página,
// las tablas rayadas y los renglones de los resúmenes.

/// Los tonos de los reportes. Son los mismos que los del Excel, para que los
/// dos archivos se parezcan.
abstract final class TintaReporte {
  static const encabezado = PdfColor.fromInt(0xFF1F4E78);
  static const rayado = PdfColor.fromInt(0xFFF2F2F2);
  static const destacado = PdfColor.fromInt(0xFFDDEBF7);
  static const linea = PdfColor.fromInt(0xFFD9D9D9);
  static const tenue = PdfColor.fromInt(0xFF595959);
}

/// Carta vertical con los márgenes de los reportes: es la hoja que hay en
/// cualquier impresora de oficina.
final PdfPageFormat hojaReporte = PdfPageFormat.letter.copyWith(
  marginLeft: 40,
  marginRight: 40,
  marginTop: 36,
  marginBottom: 36,
);

/// De quién es el reporte y de qué: a la izquierda la lavandería —logo,
/// nombre, dirección y contacto—, a la derecha el reporte, su periodo y
/// cuándo se sacó. Se repite arriba de cada página.
///
/// Sin datos de la empresa, el reporte ocupa todo el renglón.
class EncabezadoReporte extends pw.StatelessWidget {
  EncabezadoReporte({
    required this.titulo,
    required this.periodo,
    required this.generado,
    this.empresa,
    this.logo,
  });

  final String titulo;
  final String periodo;
  final DateTime generado;
  final EmpresaData? empresa;
  final pw.MemoryImage? logo;

  static const double _altoLogo = 48;

  @override
  pw.Widget build(pw.Context context) {
    final logo = this.logo;
    final nombre = empresa?.nombre ?? '';
    final direccion = empresa?.direccionImpresa ?? '';
    final contacto = (empresa?.contacto ?? const <String>[]).join('  ·  ');
    final hayEmpresa =
        logo != null ||
        nombre.isNotEmpty ||
        direccion.isNotEmpty ||
        contacto.isNotEmpty;

    final reporte = pw.Column(
      crossAxisAlignment: hayEmpresa
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(periodo, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generado el ${generado.formatFullDate}',
          style: const pw.TextStyle(fontSize: 8, color: TintaReporte.tenue),
        ),
      ],
    );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: TintaReporte.linea)),
      ),
      child: hayEmpresa
          ? pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    height: _altoLogo,
                    constraints: const pw.BoxConstraints(maxWidth: 96),
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (nombre.isNotEmpty)
                        pw.Text(
                          nombre,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (direccion.isNotEmpty) _DatoEmpresa(direccion),
                      if (contacto.isNotEmpty) _DatoEmpresa(contacto),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                reporte,
              ],
            )
          : reporte,
    );
  }
}

class _DatoEmpresa extends pw.StatelessWidget {
  _DatoEmpresa(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1),
      child: pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 8, color: TintaReporte.tenue),
      ),
    );
  }
}

/// "Página 2 de 3", abajo a la derecha.
class PieReporte extends pw.StatelessWidget {
  PieReporte({required this.pagina, required this.paginas});

  final int pagina;
  final int paginas;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página $pagina de $paginas',
        style: const pw.TextStyle(fontSize: 8, color: TintaReporte.tenue),
      ),
    );
  }
}

/// Una tabla con encabezado oscuro y renglones rayados. Al partirse entre
/// páginas repite el encabezado.
class TablaReporte extends pw.StatelessWidget {
  TablaReporte({
    required this.columnas,
    required this.filas,
    required this.alineaciones,
    required this.anchos,
  });

  final List<String> columnas;
  final List<List<String>> filas;

  /// Por índice de columna.
  final Map<int, pw.Alignment> alineaciones;

  /// Proporciones por índice de columna: `FlexColumnWidth`.
  final List<double> anchos;

  @override
  pw.Widget build(pw.Context context) {
    return pw.TableHelper.fromTextArray(
      headers: columnas,
      data: filas,
      headerCount: 1,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: TintaReporte.encabezado),
      cellStyle: const pw.TextStyle(fontSize: 9),
      // El rayado: un renglón sí y uno no, como en los listados.
      oddRowDecoration: const pw.BoxDecoration(color: TintaReporte.rayado),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: TintaReporte.linea, width: 0.5),
        ),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerAlignment: pw.Alignment.center,
      cellAlignments: alineaciones,
      columnWidths: {
        for (final (indice, ancho) in anchos.indexed)
          indice: pw.FlexColumnWidth(ancho),
      },
    );
  }
}

/// El título de una parte del reporte que va fuera del resumen: "Detalle de
/// pagos".
class SeccionReporte extends pw.StatelessWidget {
  SeccionReporte(this.texto);

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

/// El recuadro de un resumen. Va entero en una página: partido, deja un
/// recuadro vacío al pie de una y sus cifras en la siguiente.
class RecuadroReporte extends pw.StatelessWidget {
  RecuadroReporte({required this.children});

  final List<pw.Widget> children;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Inseparable(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: TintaReporte.linea),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// El título de un grupo dentro de un resumen: "COBRADO VS. PENDIENTE".
class TituloResumen extends pw.StatelessWidget {
  TituloResumen(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        texto.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          letterSpacing: 0.8,
          color: TintaReporte.tenue,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}

/// Una etiqueta y su importe; a la derecha, si lleva, qué parte es.
class RenglonResumen extends pw.StatelessWidget {
  RenglonResumen(this.etiqueta, this.valor, {this.porcentaje});

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
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: TintaReporte.tenue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `38.6 %`, o `null` si no hay de qué sacar la parte.
  static String? porcentajeDe(double parte, double de) =>
      de > 0 ? '${(parte / de * 100).toStringAsFixed(1)} %' : null;
}

/// Un total que se tiene que ver: va sobre fondo.
class DestacadoReporte extends pw.StatelessWidget {
  DestacadoReporte(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  pw.Widget build(pw.Context context) {
    final estilo = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: TintaReporte.destacado,
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

/// Un aviso en gris cuando una parte del reporte no tiene nada.
class VacioReporte extends pw.StatelessWidget {
  VacioReporte(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 10, color: TintaReporte.tenue),
      ),
    );
  }
}
