import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/assets.gen.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/animated_image_dialog.dart';

class SuccessDialog extends StatelessWidget {
  const SuccessDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedImageDialog(
      title: 'Éxito',
      message: message,
      animation: Assets.success,
      showAction: false,
    );
  }
}
