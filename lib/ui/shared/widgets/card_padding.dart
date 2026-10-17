import 'package:flutter/material.dart';

/// Una tarjeta con el relleno que usan los bloques de la aplicación.
class CardPadding extends StatelessWidget {
  const CardPadding({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(15),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
  }
}
