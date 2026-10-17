import 'package:flutter/material.dart';

/// Quita el valor de un campo: la fecha elegida, el filtro aplicado.
///
/// No borra registros; para eso están las acciones de la tabla.
class DeleteButton extends StatelessWidget {
  const DeleteButton({super.key, this.onPressed, this.tooltip = 'Quitar'});

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.cancel),
      color: Theme.of(context).colorScheme.primary,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
