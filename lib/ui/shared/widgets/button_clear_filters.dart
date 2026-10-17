import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Devuelve un listado a sus filtros de omisión.
///
/// Sólo se muestra cuando hay algo que limpiar: un botón siempre visible que
/// la mitad del tiempo no hace nada enseña al usuario a ignorarlo.
class ButtonClearFilters extends StatelessWidget {
  const ButtonClearFilters({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(IconsManager.clearFilters),
      label: const Text('Limpiar filtros'),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(10)),
    );
  }
}
