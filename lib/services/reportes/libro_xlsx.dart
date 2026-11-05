import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Un libro de Excel de una hoja, escrito a mano.
///
/// Un `.xlsx` es un zip con unos cuantos XML. Se escribe aquí y no con un
/// paquete porque el de Excel más usado pide una versión de `xml` que choca
/// con la que necesita `pdf`, y el ticket depende de `pdf`. Para una hoja con
/// texto, importes y fechas basta con lo que hay aquí.
///
/// Los importes y las fechas van como números con formato, no como texto:
/// así en Excel se suman, se ordenan y se filtran.
class LibroXlsx {
  const LibroXlsx();

  Uint8List generar(HojaXlsx hoja) {
    final libro = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _tiposDeContenido))
      ..addFile(ArchiveFile.string('_rels/.rels', _relaciones))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _libro(hoja)))
      ..addFile(
        ArchiveFile.string('xl/_rels/workbook.xml.rels', _relacionesLibro),
      )
      ..addFile(ArchiveFile.string('xl/styles.xml', _estilos))
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', _hoja(hoja)));

    return ZipEncoder().encodeBytes(libro);
  }

  String _libro(HojaXlsx hoja) {
    final filtro = hoja.filtro;
    final nombre = _escapar(hoja.nombre);

    return '$_cabecera'
        '<workbook xmlns="$_nsMain" xmlns:r="$_nsRelaciones">'
        '<sheets><sheet name="$nombre" sheetId="1" r:id="rId1"/></sheets>'
        // Excel guarda aquí el rango del filtro; sin este nombre, algunas
        // versiones lo quitan al abrir el archivo.
        '${filtro == null ? '' : '<definedNames><definedName '
                  'name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">'
                  "'$nombre'!${filtro.referenciaAbsoluta}"
                  '</definedName></definedNames>'}'
        '</workbook>';
  }

  String _hoja(HojaXlsx hoja) {
    final salida = StringBuffer(_cabecera)
      ..write('<worksheet xmlns="$_nsMain" xmlns:r="$_nsRelaciones">');

    // Al imprimir, todas las columnas en el ancho de la hoja: sin esto, la
    // última se iba sola a otra página.
    if (hoja.ajustarAlAncho) {
      salida.write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>');
    }

    final fijas = hoja.filasFijas;
    if (fijas > 0) {
      salida.write(
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="$fijas" topLeftCell="A${fijas + 1}" '
        'activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
      );
    }

    if (hoja.anchos.isNotEmpty) {
      salida.write('<cols>');
      for (final (indice, ancho) in hoja.anchos.indexed) {
        final columna = indice + 1;
        salida.write(
          '<col min="$columna" max="$columna" width="$ancho" '
          'customWidth="1"/>',
        );
      }
      salida.write('</cols>');
    }

    salida.write('<sheetData>');
    for (final (indiceFila, fila) in hoja.filas.indexed) {
      final numero = indiceFila + 1;
      salida.write('<row r="$numero">');
      for (final (indiceColumna, celda) in fila.indexed) {
        if (celda == null) continue;
        salida.write(_celda('${columnaXlsx(indiceColumna)}$numero', celda));
      }
      salida.write('</row>');
    }
    salida.write('</sheetData>');

    final filtro = hoja.filtro;
    if (filtro != null) {
      salida.write('<autoFilter ref="${filtro.referencia}"/>');
    }

    if (hoja.ajustarAlAncho) {
      salida.write(
        '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" '
        'header="0.3" footer="0.3"/>'
        '<pageSetup fitToWidth="1" fitToHeight="0"/>',
      );
    }

    salida.write('</worksheet>');

    return salida.toString();
  }

  String _celda(String referencia, CeldaXlsx celda) {
    final estilo = celda.estilo.index;

    return switch (celda) {
      TextoXlsx(:final texto) =>
        '<c r="$referencia" t="inlineStr" s="$estilo">'
            '<is><t xml:space="preserve">${_escapar(texto)}</t></is></c>',
      NumeroXlsx(:final numero) =>
        '<c r="$referencia" s="$estilo"><v>$numero</v></c>',
      FechaXlsx(:final fecha) =>
        '<c r="$referencia" s="$estilo"><v>${serialExcel(fecha)}</v></c>',
    };
  }

  static String _escapar(String texto) => texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Los caracteres de control no son XML válido: Excel no abriría el
      // archivo por una nota con un tabulador pegado.
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static const _cabecera =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const _nsMain =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _nsRelaciones =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _nsPaquete =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  static const _tiposDeContenido =
      '$_cabecera'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _relaciones =
      '$_cabecera'
      '<Relationships xmlns="$_nsPaquete">'
      '<Relationship Id="rId1" Type="$_nsRelaciones/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _relacionesLibro =
      '$_cabecera'
      '<Relationships xmlns="$_nsPaquete">'
      '<Relationship Id="rId1" Type="$_nsRelaciones/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="$_nsRelaciones/styles" '
      'Target="styles.xml"/>'
      '</Relationships>';

  static final String _estilos = () {
    final formatos = [
      for (final estilo in EstiloXlsx.values)
        '<xf numFmtId="${estilo.formato}" fontId="${estilo.fuente.index}" '
            'fillId="${estilo.relleno.index}" '
            'borderId="${estilo.conBorde ? 1 : 0}" xfId="0" '
            'applyNumberFormat="1" applyFont="1" applyFill="1" '
            'applyBorder="1"${estilo.centrado ? ' applyAlignment="1">'
                      '<alignment horizontal="center" vertical="center"/></xf>' : '/>'}',
    ];
    const gris = '<color rgb="FFD9D9D9"/>';

    return '$_cabecera'
        '<styleSheet xmlns="$_nsMain">'
        '<numFmts count="2">'
        '<numFmt numFmtId="$_formatoPesos" formatCode="&quot;\$&quot;#,##0.00"/>'
        '<numFmt numFmtId="$_formatoFecha" formatCode="dd/mm/yyyy hh:mm"/>'
        '</numFmts>'
        '<fonts count="${FuenteXlsx.values.length}">'
        '${FuenteXlsx.values.map((fuente) => fuente._xml).join()}'
        '</fonts>'
        '<fills count="${RellenoXlsx.values.length}">'
        '${RellenoXlsx.values.map((relleno) => relleno._xml).join()}'
        '</fills>'
        '<borders count="2">'
        '<border><left/><right/><top/><bottom/><diagonal/></border>'
        '<border><left style="thin">$gris</left><right style="thin">$gris'
        '</right><top style="thin">$gris</top><bottom style="thin">$gris'
        '</bottom><diagonal/></border>'
        '</borders>'
        '<cellStyleXfs count="1">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
        '</cellStyleXfs>'
        '<cellXfs count="${formatos.length}">${formatos.join()}</cellXfs>'
        '<cellStyles count="1">'
        '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
        '</cellStyles>'
        '</styleSheet>';
  }();
}

/// La letra de la columna [indice], contando desde cero: `A`, …, `Z`, `AA`.
String columnaXlsx(int indice) {
  var resto = indice + 1;
  var letras = '';

  while (resto > 0) {
    final residuo = (resto - 1) % 26;
    letras = String.fromCharCode(65 + residuo) + letras;
    resto = (resto - 1) ~/ 26;
  }

  return letras;
}

/// [fecha] como la cuenta Excel: días desde el 30 de diciembre de 1899, con
/// la hora como fracción del día.
///
/// Se calcula en UTC con los mismos números de la fecha local: un cambio de
/// horario en medio movería la hora una vez guardada.
double serialExcel(DateTime fecha) {
  final comoUtc = DateTime.utc(
    fecha.year,
    fecha.month,
    fecha.day,
    fecha.hour,
    fecha.minute,
    fecha.second,
  );
  final milisegundos = comoUtc.difference(DateTime.utc(1899, 12, 30));

  return milisegundos.inMilliseconds / Duration.millisecondsPerDay;
}

/// Una hoja: sus filas, el ancho de sus columnas y, si lleva, el rango del
/// filtro y cuántas filas se quedan fijas arriba al desplazarse.
class HojaXlsx {
  const HojaXlsx({
    required this.nombre,
    required this.filas,
    this.anchos = const [],
    this.filtro,
    this.filasFijas = 0,
    this.ajustarAlAncho = false,
  });

  final String nombre;

  /// Una lista por fila; `null` deja la celda vacía.
  final List<List<CeldaXlsx?>> filas;

  /// En caracteres, como los mide Excel.
  final List<double> anchos;

  final RangoXlsx? filtro;
  final int filasFijas;

  /// Si al imprimir las columnas se encogen al ancho de la hoja.
  final bool ajustarAlAncho;
}

/// Un rectángulo de celdas, con filas y columnas contadas desde cero.
class RangoXlsx {
  const RangoXlsx({
    required this.filaInicial,
    required this.filaFinal,
    required this.columnas,
  });

  final int filaInicial;
  final int filaFinal;
  final int columnas;

  String get referencia =>
      'A${filaInicial + 1}:${columnaXlsx(columnas - 1)}${filaFinal + 1}';

  String get referenciaAbsoluta =>
      '\$A\$${filaInicial + 1}:'
      '\$${columnaXlsx(columnas - 1)}\$${filaFinal + 1}';
}

sealed class CeldaXlsx {
  const CeldaXlsx(this.estilo);

  final EstiloXlsx estilo;
}

class TextoXlsx extends CeldaXlsx {
  const TextoXlsx(this.texto, [super.estilo = EstiloXlsx.texto]);

  final String texto;
}

class NumeroXlsx extends CeldaXlsx {
  const NumeroXlsx(this.numero, [super.estilo = EstiloXlsx.pesos]);

  final double numero;
}

class FechaXlsx extends CeldaXlsx {
  const FechaXlsx(this.fecha, [super.estilo = EstiloXlsx.fecha]);

  final DateTime fecha;
}

const _formatoPesos = 164;
const _formatoFecha = 165;

/// El porcentaje con dos decimales es de los que Excel trae de fábrica.
const _formatoPorcentaje = 10;

/// Los estilos de celda del libro. El índice de cada uno es su lugar en la
/// lista de estilos del archivo, que es como la celda lo nombra.
enum EstiloXlsx {
  // El primero es el de omisión de Excel: tiene que ir sin nada.
  normal(),
  titulo(fuente: FuenteXlsx.titulo),
  nota(fuente: FuenteXlsx.nota),
  encabezado(
    fuente: FuenteXlsx.encabezado,
    relleno: RellenoXlsx.encabezado,
    conBorde: true,
    centrado: true,
  ),
  texto(conBorde: true),
  textoCentrado(conBorde: true, centrado: true),
  pesos(formato: _formatoPesos, conBorde: true),
  fecha(formato: _formatoFecha, conBorde: true),
  textoRayado(relleno: RellenoXlsx.rayado, conBorde: true),
  textoCentradoRayado(
    relleno: RellenoXlsx.rayado,
    conBorde: true,
    centrado: true,
  ),
  pesosRayado(
    formato: _formatoPesos,
    relleno: RellenoXlsx.rayado,
    conBorde: true,
  ),
  fechaRayada(
    formato: _formatoFecha,
    relleno: RellenoXlsx.rayado,
    conBorde: true,
  ),
  seccion(fuente: FuenteXlsx.negrita),
  etiqueta(),
  pesosResumen(formato: _formatoPesos),
  porcentaje(formato: _formatoPorcentaje),
  etiquetaTotal(fuente: FuenteXlsx.negrita, relleno: RellenoXlsx.total),
  pesosTotal(
    formato: _formatoPesos,
    fuente: FuenteXlsx.negrita,
    relleno: RellenoXlsx.total,
  ),
  entero();

  const EstiloXlsx({
    this.formato = 0,
    this.fuente = FuenteXlsx.normal,
    this.relleno = RellenoXlsx.ninguno,
    this.conBorde = false,
    this.centrado = false,
  });

  /// El número del formato: uno de los de fábrica de Excel o uno de los que
  /// declara el libro.
  final int formato;
  final FuenteXlsx fuente;
  final RellenoXlsx relleno;
  final bool conBorde;
  final bool centrado;

  /// El mismo estilo en un renglón rayado de la tabla.
  EstiloXlsx get rayado => switch (this) {
    texto => textoRayado,
    textoCentrado => textoCentradoRayado,
    pesos => pesosRayado,
    fecha => fechaRayada,
    _ => this,
  };
}

/// Las fuentes del libro. El índice de cada una es su lugar en el archivo.
enum FuenteXlsx {
  normal('<sz val="11"/>'),
  negrita('<b/><sz val="11"/>'),
  titulo('<b/><sz val="14"/>'),
  encabezado('<b/><sz val="11"/><color rgb="FFFFFFFF"/>'),
  nota('<sz val="10"/><color rgb="FF595959"/>');

  const FuenteXlsx(this._propiedades);

  final String _propiedades;

  String get _xml =>
      '<font>$_propiedades<name val="Calibri"/><family val="2"/></font>';
}

/// Los rellenos del libro. El índice de cada uno es su lugar en el archivo.
enum RellenoXlsx {
  // Los dos primeros los exige el formato, y en este orden.
  ninguno(null),
  gris125(null),
  encabezado('FF1F4E78'),
  rayado('FFF2F2F2'),
  total('FFDDEBF7');

  const RellenoXlsx(this._color);

  /// En `null` en los dos que exige el formato, que no son de un color.
  final String? _color;

  String get _xml {
    final color = _color;
    final patron = switch (this) {
      ninguno => '<patternFill patternType="none"/>',
      gris125 => '<patternFill patternType="gray125"/>',
      _ =>
        '<patternFill patternType="solid"><fgColor rgb="$color"/>'
            '<bgColor indexed="64"/></patternFill>',
    };

    return '<fill>$patron</fill>';
  }
}
