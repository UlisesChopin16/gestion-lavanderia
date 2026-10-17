import 'package:flutter/material.dart';

/// Cambia entre el indicador de carga y el contenido sin que el bloque dé un
/// salto: los dos se cruzan en la misma posición.
class AnimatingLoading extends StatelessWidget {
  const AnimatingLoading({
    super.key,
    required this.isLoading,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  final bool isLoading;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: duration,
      crossFadeState: isLoading
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: const Center(child: CircularProgressIndicator()),
      secondChild: child,
    );
  }
}
