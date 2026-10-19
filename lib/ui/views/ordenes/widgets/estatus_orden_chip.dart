import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';

export 'package:gestion_lavanderia/types/estatus_orden_type.dart';

/// En qué punto de su ciclo está una orden, como etiqueta de color.
///
/// El color y el icono los trae el propio estatus y no el tema: son cuatro
/// estados que conviven en la misma lista —en curso, pagada, cerrada,
/// cancelada—, y el par de contenedores con el que `EstatusChip` distingue lo
/// vigente de lo dado de baja no alcanza para cuatro.
///
/// El color va en el icono y en el contorno, no en el texto: sobre el fondo
/// claro de la etiqueta, un "Cerrada" en verde se lee peor que en el color de
/// la tabla.
class EstatusOrdenChip extends StatelessWidget {
  const EstatusOrdenChip({super.key, required this.estatus});

  final EstatusOrdenType estatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = estatus.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(estatus.icon, size: 14, color: color),
          // Flexible porque la etiqueta vive en una celda angosta: sin esto,
          // "Cancelada" desborda la columna en lugar de bajar de línea.
          Flexible(
            child: Text(
              estatus.value,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
