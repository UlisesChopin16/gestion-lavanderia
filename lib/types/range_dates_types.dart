/// Rangos de fecha predefinidos del selector de fechas.
///
/// El rango se calcula al pedirlo y no se guarda, para que "un mes" siga
/// significando un mes desde hoy aunque la aplicación lleve días abierta.
enum RangeDatesTypes {
  week(title: 'Una semana'),
  month(title: 'Un mes'),
  threeMonths(title: 'Tres meses');

  final String title;

  const RangeDatesTypes({required this.title});

  /// El rango `[desde, hasta]`, donde `hasta` es hoy a medianoche.
  ///
  /// Se recorta la hora porque las comparaciones de la consulta son por día:
  /// con la hora puesta, un registro creado hoy por la tarde quedaría fuera.
  List<DateTime> range({DateTime? ahora}) {
    final today = ahora ?? DateTime.now();
    final now = DateTime(today.year, today.month, today.day);

    return switch (this) {
      RangeDatesTypes.week => [now.subtract(const Duration(days: 7)), now],
      RangeDatesTypes.month => [
        DateTime(now.year, now.month - 1, now.day),
        now,
      ],
      RangeDatesTypes.threeMonths => [
        DateTime(now.year, now.month - 3, now.day),
        now,
      ],
    };
  }
}
