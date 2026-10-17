import 'package:flutter/material.dart';

/// Encabezado de una sección dentro de una pantalla o un diálogo.
class TitleContainer extends StatelessWidget {
  const TitleContainer({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final icon = this.icon;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 15,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, color: primary),
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
