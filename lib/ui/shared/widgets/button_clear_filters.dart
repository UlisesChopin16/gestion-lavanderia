import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Devuelve un listado a sus filtros de omisión.
///
/// Está siempre a la vista, aunque no haya nada que limpiar: cuando sólo
/// aparecía al haber filtros, el renglón de controles cambiaba de ancho al
/// escribir en el buscador y el botón iba y venía bajo el cursor.
///
/// Va en tono lleno y no como un botón de contorno: entre desplegables que
/// también son recuadros con borde, el de antes se perdía y había que buscarlo
/// a propósito. No usa el color primario, que es el del botón de agregar, para
/// que no compitan por ser la acción principal del listado.
class ButtonClearFilters extends StatelessWidget {
  const ButtonClearFilters({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(IconsManager.clearFilters, size: 20),
      label: const Text('Limpiar filtros'),
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          // El borde lo despega del fondo de la tarjeta en el tema oscuro,
          // donde el relleno del botón y la tarjeta se parecen.
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
