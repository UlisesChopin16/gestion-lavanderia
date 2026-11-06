import 'package:gestion_lavanderia/types/unit_type.dart';

/// Un renglón de ropa como se lee en los reportes: `3 Piezas Camisa`,
/// `2.5 Kgs Ropa de color`.
String describirConcepto({
  required String nombre,
  required double cantidad,
  required UnitType unidad,
}) {
  final numero = cantidad == cantidad.roundToDouble()
      ? cantidad.toStringAsFixed(0)
      : cantidad.toStringAsFixed(1);

  return '$numero ${cantidad == 1 ? unidad.value : unidad.plural} $nombre';
}

/// Días de calendario entre dos fechas, sin contar la hora: algo de anoche
/// ya es de hace un día aunque no hayan pasado veinticuatro horas.
int diasEntre(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;
