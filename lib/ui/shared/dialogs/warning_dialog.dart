import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/assets.gen.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/animated_image_dialog.dart';

/// Pregunta de la que depende una acción: devuelve `true` sólo si se confirma.
class WarningDialog extends StatelessWidget {
  const WarningDialog({
    super.key,
    required this.message,
    this.title = 'Advertencia',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedImageDialog(
      title: title,
      message: message,
      animation: Assets.warning,
      closeText: 'Cancelar',
    );
  }
}
