import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Una tabla de texto con encabezado y renglones rayados, para el detalle de
/// una pantalla de estadísticas.
///
/// Es también la forma de leer la pantalla sin las gráficas: lo que ellas
/// dibujan sale de estos renglones.
class TablaEstadistica extends StatelessWidget {
  const TablaEstadistica({
    super.key,
    required this.columnas,
    required this.filas,
    required this.alineaciones,
    required this.anchos,
    this.anchoMinimo = 760,
  });

  final List<String> columnas;
  final List<List<String>> filas;

  /// Una por columna.
  final List<TextAlign> alineaciones;

  /// Proporciones de cada columna: `FlexColumnWidth`.
  final List<double> anchos;

  /// Por debajo de este ancho la tabla se desplaza de lado en lugar de
  /// apretar las columnas.
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estiloEncabezado = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final estiloCelda = theme.textTheme.bodyMedium;

    TableRow renglon(List<String> celdas, {TextStyle? estilo, Color? fondo}) {
      return TableRow(
        decoration: BoxDecoration(
          color: fondo,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        children: [
          for (final (indice, celda) in celdas.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                celda,
                textAlign: alineaciones[indice],
                style: estilo,
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = math.max(constraints.maxWidth, anchoMinimo);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            child: Table(
              columnWidths: {
                for (final (indice, flex) in anchos.indexed)
                  indice: FlexColumnWidth(flex),
              },
              children: [
                renglon(columnas, estilo: estiloEncabezado),
                for (final (indice, fila) in filas.indexed)
                  renglon(
                    fila,
                    estilo: estiloCelda,
                    // El rayado: un renglón sí y uno no, como en los listados.
                    fondo: indice.isOdd
                        ? scheme.onSurface.withValues(alpha: 0.04)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
