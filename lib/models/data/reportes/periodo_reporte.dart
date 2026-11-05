import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/types/range_dates_types.dart';

/// Los días que abarca un reporte, de [desde] a [hasta], los dos incluidos.
///
/// Son días y no instantes: se guardan a medianoche, y la consulta va de la
/// medianoche de [desde] a la del día siguiente a [hasta] —[inicio] y [fin]—.
/// Así una orden de hoy por la tarde entra en el reporte de hoy.
@immutable
class RangoReporte {
  /// Acepta las fechas en cualquier orden y con cualquier hora.
  factory RangoReporte(DateTime una, DateTime otra) {
    final a = _dia(una);
    final b = _dia(otra);

    return a.isAfter(b) ? RangoReporte._(b, a) : RangoReporte._(a, b);
  }

  const RangoReporte._(this.desde, this.hasta);

  final DateTime desde;
  final DateTime hasta;

  DateTime get inicio => desde;

  /// Exclusivo: la medianoche que cierra el último día.
  DateTime get fin => DateTime(hasta.year, hasta.month, hasta.day + 1);

  /// Si abarca más que "un mes": de ahí en adelante el reporte sale en
  /// Excel, que con muchas órdenes se filtra y se suma mejor que un PDF.
  ///
  /// "Un mes" es el mismo que el del atajo del selector de fechas: del mismo
  /// día del mes anterior a hoy.
  bool get pasaDeUnMes =>
      desde.isBefore(DateTime(hasta.year, hasta.month - 1, hasta.day));

  FormatoReporte get formato =>
      pasaDeUnMes ? FormatoReporte.excel : FormatoReporte.pdf;

  static DateTime _dia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  @override
  bool operator ==(Object other) =>
      other is RangoReporte && other.desde == desde && other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

/// En qué archivo sale un reporte.
enum FormatoReporte {
  pdf(titulo: 'PDF', extension: 'pdf'),
  excel(titulo: 'Excel', extension: 'xlsx');

  const FormatoReporte({required this.titulo, required this.extension});

  final String titulo;
  final String extension;
}

/// Los periodos que se pueden pedir para un reporte.
///
/// Semana, mes y tres meses son los mismos que los atajos del selector de
/// fechas, para que "un mes" signifique lo mismo en toda la aplicación.
enum PeriodoReporte {
  hoy(titulo: 'Hoy'),
  semana(titulo: 'Una semana'),
  mes(titulo: 'Un mes'),
  tresMeses(titulo: 'Tres meses'),
  anio(titulo: 'Un año'),
  rango(titulo: 'Otras fechas');

  const PeriodoReporte({required this.titulo});

  final String titulo;

  /// Los días del periodo contados hacia atrás desde [ahora], o `null` en
  /// [rango], cuyas fechas las elige el usuario.
  RangoReporte? rangoDesde(DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    RangoReporte atajo(RangeDatesTypes tipo) {
      final [desde, hasta] = tipo.range(ahora: ahora);
      return RangoReporte(desde, hasta);
    }

    return switch (this) {
      PeriodoReporte.hoy => RangoReporte(hoy, hoy),
      PeriodoReporte.semana => atajo(RangeDatesTypes.week),
      PeriodoReporte.mes => atajo(RangeDatesTypes.month),
      PeriodoReporte.tresMeses => atajo(RangeDatesTypes.threeMonths),
      PeriodoReporte.anio => RangoReporte(
        DateTime(hoy.year - 1, hoy.month, hoy.day),
        hoy,
      ),
      PeriodoReporte.rango => null,
    };
  }
}
