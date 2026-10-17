import 'package:flutter/material.dart';

/// Muestra u oculta [child] con un desvanecido y un deslizamiento lateral.
///
/// La versión anterior guardaba la visibilidad en el estado y la recalculaba
/// desde `didUpdateWidget` y desde el `onEnd` de la animación, de modo que
/// cada animación terminaba provocando otra reconstrucción. `AnimatedSwitcher`
/// hace lo mismo sin estado propio: la visibilidad es la que dice quien la usa.
class AnimatingComponent extends StatelessWidget {
  const AnimatingComponent({
    super.key,
    required this.child,
    required this.showComponent,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final bool showComponent;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: showComponent ? child : const SizedBox.shrink(),
    );
  }
}
