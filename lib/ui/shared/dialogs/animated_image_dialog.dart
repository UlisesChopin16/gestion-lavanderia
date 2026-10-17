import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/assets.gen.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/base_dialog.dart';

/// Diálogo con una animación arriba y un mensaje: la forma que comparten los
/// avisos de éxito, error y advertencia.
///
/// Recibe la animación como [LottieGenImage] y no como ruta de texto para que
/// un nombre de archivo mal escrito sea un error de compilación.
class AnimatedImageDialog extends StatelessWidget {
  const AnimatedImageDialog({
    super.key,
    required this.title,
    required this.message,
    required this.animation,
    this.showAction = true,
    this.actionText = 'Aceptar',
    this.closeText = 'Cerrar',
    this.onActionPressed,
  });

  final String title;
  final String message;
  final LottieGenImage animation;
  final bool showAction;
  final String actionText;
  final String closeText;
  final VoidCallback? onActionPressed;

  static const double _animationSize = 150;

  @override
  Widget build(BuildContext context) {
    final labelLarge = Theme.of(context).textTheme.labelLarge;

    return BaseDialog(
      title: title,
      icon: animation.lottie(
        width: _animationSize,
        height: _animationSize,
        fit: BoxFit.contain,
        repeat: true,
      ),
      actionText: actionText,
      closeText: closeText,
      showAction: showAction,
      autofocusAction: true,
      onActionPressed: onActionPressed,
      content: SingleChildScrollView(
        child: Text(message, textAlign: TextAlign.center, style: labelLarge),
      ),
    );
  }
}
