import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/assets.gen.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/animated_image_dialog.dart';

/// Pregunta de la que depende una acción: devuelve `true` sólo si se confirma.
class WarningDialog extends StatelessWidget {
  const WarningDialog({
    super.key,
    required this.message,
    this.title = 'Advertencia',
    this.actionText = 'Aceptar',
  });

  final String title;
  final String message;

  /// Lo que dice el botón que confirma: mejor lo que va a pasar que
  /// "Aceptar".
  final String actionText;

  @override
  Widget build(BuildContext context) {
    return AnimatedImageDialog(
      title: title,
      message: message,
      animation: Assets.warning,
      actionText: actionText,
      closeText: 'Cancelar',
    );
  }
}
