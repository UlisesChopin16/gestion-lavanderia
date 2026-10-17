import 'package:flutter/material.dart';

/// Cubre la pantalla mientras una operación está en curso.
///
/// El velo no es decorativo: impide que se vuelva a pulsar un botón que ya
/// está guardando, que es la forma habitual de duplicar un registro.
class BlockProgress extends StatelessWidget {
  const BlockProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
