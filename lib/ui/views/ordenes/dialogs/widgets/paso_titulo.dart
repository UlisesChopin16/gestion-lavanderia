import 'package:flutter/material.dart';

/// El número y el nombre de un paso del alta de una orden.
///
/// Los pasos van numerados para que se lea de un vistazo en qué orden se
/// llena el diálogo: primero el cliente, después la ropa. No se bloquean entre
/// sí —se puede elegir la ropa antes que el cliente—, pero el orden sugerido
/// es el que evita volver atrás.
class PasoTitulo extends StatelessWidget {
  const PasoTitulo({
    super.key,
    required this.numero,
    required this.titulo,
    this.acompanante,
  });

  final String numero;
  final String titulo;

  /// Lo que va al final del renglón, cuando el paso tiene algo que decir: el
  /// total de prendas, por ejemplo.
  final Widget? acompanante;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      spacing: 10,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primary,
          child: Text(
            numero,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: Text(titulo, style: theme.textTheme.titleMedium)),
        ?acompanante,
      ],
    );
  }
}
