import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Invierte el sentido del ordenamiento.
///
/// Muestra el sentido actual, no el que se obtendría al pulsarlo: la flecha y
/// el texto dicen cómo está ordenada la lista en este momento.
class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.isAscending, this.onPressed});

  final bool isAscending;
  final VoidCallback? onPressed;

  String get _label => isAscending ? 'Ascendente' : 'Descendente';

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(IconsManager.getSortIcon(isAscending)),
      label: Text(_label),
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
    );
  }
}
