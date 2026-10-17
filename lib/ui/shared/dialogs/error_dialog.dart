import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/assets.gen.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/animated_image_dialog.dart';

class ErrorDialog extends StatelessWidget {
  const ErrorDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedImageDialog(
      title: 'Error',
      message: message,
      animation: Assets.error,
      showAction: false,
    );
  }
}
