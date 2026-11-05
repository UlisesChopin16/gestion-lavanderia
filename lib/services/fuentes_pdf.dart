import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// La fuente de la aplicación para los PDF que genera: el ticket y los
/// reportes salen con la misma letra que la pantalla.
abstract final class FuentesPdf {
  static const _ruta = 'assets/fonts/Poppins';

  /// Las fuentes se leen una vez por sesión: el mismo documento se vuelve a
  /// generar cada vez que se pide, y la fuente no cambia.
  static final _cache = <String, pw.Font>{};

  /// El tema de un documento: Poppins normal y, para las negritas, seminegra.
  static Future<pw.ThemeData> tema() async => pw.ThemeData.withFont(
    base: await _fuente('Regular'),
    bold: await _fuente('SemiBold'),
  );

  static Future<pw.Font> _fuente(String peso) async {
    final cache = _cache[peso];
    if (cache != null) return cache;

    final datos = await rootBundle.load('$_ruta/Poppins-$peso.ttf');

    return _cache[peso] = pw.Font.ttf(datos);
  }
}
