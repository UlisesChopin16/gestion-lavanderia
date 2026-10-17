import 'package:gestion_lavanderia/utils/constants_manager.dart';

extension DateTimeExt on DateTime {
  String get formatDate => ConstantsManager.formatDate(this);
  String get formatFullDate => ConstantsManager.fullDateFormat(this);

  /// Esta fecha, o el extremo más cercano si queda fuera de `[min, max]`.
  ///
  /// El calendario lanza una excepción si la fecha inicial está fuera del
  /// rango que puede mostrar, así que se recorta antes de abrirlo.
  DateTime clampDate(DateTime min, DateTime max) {
    if (isBefore(min)) return min;
    if (isAfter(max)) return max;
    return this;
  }
}

/// El mismo formato para una fecha que puede faltar: una fecha de eliminación
/// vacía se muestra como `N/A` en lugar de obligar a cada celda a comprobarlo.
extension DateTimeNullExt on DateTime? {
  String get formatDate => ConstantsManager.formatDate(this);
  String get formatFullDate => ConstantsManager.fullDateFormat(this);
}
