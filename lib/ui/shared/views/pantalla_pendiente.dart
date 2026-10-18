import 'package:flutter/material.dart';

/// El lugar de un módulo que todavía no se ha migrado.
///
/// Está para que la navegación del home esté completa desde el principio: al
/// portar cada pantalla se cambia su entrada en `HomeTabsType` y lo demás
/// sigue igual. Dice qué falta en lugar de dejar un hueco en blanco, que se
/// confunde con una pantalla que no cargó.
class PantallaPendiente extends StatelessWidget {
  const PantallaPendiente({super.key, required this.modulo});

  /// El nombre del módulo, tal como aparece en la navegación.
  final String modulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            Text(modulo, style: theme.textTheme.titleLarge),
            Text(
              'Este módulo todavía no está disponible.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
