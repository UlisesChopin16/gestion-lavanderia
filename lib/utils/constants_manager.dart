import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Medidas y formatos que la interfaz repite.
abstract final class ConstantsManager {
  /// El nombre de la aplicación, como aparece en la ventana y en el menú.
  static const String appName = 'Gestión Lavandería';

  /// Anchos a partir de los que la interfaz cambia de disposición.
  static const double smallScreen = 600.0;
  static const double mediumScreen = 900.0;
  static const double largeScreen = 1200.0;

  static const String locale = 'es_ES';

  static const String maskDate = 'dd/MMM/yyyy';
  static const String maskTime = 'HH:mm';
  static const String maskDateTime = 'dd/MMM/yyyy HH:mm';

  /// Lo que se muestra en lugar de una fecha u otro dato ausente.
  static const String emptyValue = 'N/A';

  /// Carga los nombres de meses y días en español.
  ///
  /// `DateFormat` sólo conoce `en_US` hasta que se inicializa el idioma, y
  /// falla con una excepción al formatear en otro. Está aquí, y no suelto en
  /// `main`, para que la aplicación y las pruebas usen la misma llamada.
  static void initFormats() => initializeDateFormatting(locale);

  /// Sólo el día: `17/oct/2026`.
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return emptyValue;

    return DateFormat(maskDate, locale).format(dateTime);
  }

  /// Día y hora: `17/oct/2026 14:30`.
  static String fullDateFormat(DateTime? dateTime) {
    if (dateTime == null) return emptyValue;

    return DateFormat(maskDateTime, locale).format(dateTime);
  }
}
