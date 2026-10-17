import 'package:flutter/material.dart';

/// Esqueleto de los diálogos de la aplicación.
///
/// Se cierra devolviendo `true` cuando se acepta y `false` cuando se cancela,
/// de modo que `await showDialog<bool>(...)` basta para saber qué eligió el
/// usuario; un cierre con la tecla Escape o tocando fuera devuelve `null`, que
/// quien llama trata como cancelado.
class BaseDialog extends StatelessWidget {
  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.actionText = 'Aceptar',
    this.closeText = 'Cerrar',
    this.showAction = true,
    this.showCloseButton = true,
    this.onActionPressed,
    this.autofocusAction = false,
  });

  final String title;
  final Widget content;
  final Widget? icon;
  final String actionText;
  final String closeText;

  /// Si se muestra el botón que acepta. Un diálogo que sólo informa (un error,
  /// por ejemplo) no lo necesita.
  final bool showAction;
  final bool showCloseButton;

  /// Se ejecuta antes de cerrar. El cierre lo hace el diálogo, así que quien
  /// lo usa no tiene que acordarse de llamar a `pop`.
  final VoidCallback? onActionPressed;
  final bool autofocusAction;

  @override
  Widget build(BuildContext context) {
    final labelLarge = Theme.of(context).textTheme.labelLarge;

    return AlertDialog.adaptive(
      icon: icon,
      title: Text(title, textAlign: TextAlign.center),
      content: content,
      actions: [
        if (showCloseButton)
          TextButton(
            autofocus: !showAction && autofocusAction,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              closeText,
              style: labelLarge?.copyWith(color: Colors.redAccent),
            ),
          ),
        if (showAction)
          FilledButton(
            autofocus: autofocusAction,
            onPressed: () {
              onActionPressed?.call();
              Navigator.of(context).pop(true);
            },
            child: Text(actionText),
          ),
      ],
    );
  }
}
