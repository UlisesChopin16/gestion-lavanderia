import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';

export 'package:gestion_lavanderia/types/estatus_type.dart';

/// El estatus de un renglón, como etiqueta de color.
///
/// En una lista donde la mayoría está activa, lo que hay que encontrar de un
/// vistazo es lo dado de baja; con el estatus escrito como texto plano todos
/// los renglones se leen igual.
class EstatusChip extends StatelessWidget {
  const EstatusChip({super.key, required this.estatus});

  final EstatusType estatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activo = estatus == EstatusType.activo;

    final fondo = activo ? scheme.primaryContainer : scheme.errorContainer;
    final texto = activo ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estatus.value,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: texto),
      ),
    );
  }
}
