import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/base_dialog.dart';

/// El lugar de un diálogo que todavía no se ha migrado.
///
/// Es lo que `PantallaPendiente` es para un módulo entero, pero para lo que se
/// abre encima de un listado: la pantalla queda armada y con sus botones en su
/// sitio, y portar cada diálogo es cambiar lo que ese botón abre. Dice qué
/// falta en lugar de no hacer nada al pulsarlo, que se confunde con un botón
/// roto.
class DialogoPendiente extends StatelessWidget {
  const DialogoPendiente({super.key, required this.titulo, this.detalle = ''});

  /// Lo que el diálogo hará cuando exista: "Nueva orden", "Historial de la
  /// orden".
  final String titulo;

  /// Sobre qué registro se iba a abrir, cuando lo hay: el folio de la orden,
  /// por ejemplo. Vacío cuando el diálogo no trabaja sobre ninguno.
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseDialog(
      title: titulo,
      // Sólo informa: no hay nada que aceptar todavía.
      showAction: false,
      closeText: 'Entendido',
      icon: Icon(Icons.construction_rounded, color: theme.colorScheme.outline),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (detalle.isNotEmpty)
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          Text(
            'Esta parte del módulo todavía no está disponible.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
