import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Una barra de [BarrasHorizontales].
@immutable
class DatoBarra {
  const DatoBarra({
    required this.etiqueta,
    required this.valor,
    required this.valorTexto,
    this.icono,
    this.nota,
    this.detalle,
  });

  final String etiqueta;

  /// Lo que mide la barra, contra la mayor de la lista.
  final double valor;

  /// El valor como se lee, a la derecha: `$2,057.00`, `12 órdenes`.
  final String valorTexto;

  final IconData? icono;

  /// En chico, junto al valor: `55 %`.
  final String? nota;

  /// Lo que dice el recuadro al pasar el mouse. Sin él, no sale.
  final String? detalle;
}

/// Una lista de barras horizontales sobre una misma base, en el orden en que
/// llegan, con su nombre y su valor escritos.
///
/// Barras y no un pastel: comparar largos sobre una misma base se lee bien,
/// comparar ángulos no. Y un solo color, porque lo que se compara es cuánto,
/// no quién: el nombre de cada una va escrito a su lado. La mayor llena la
/// pista y las demás, su parte.
class BarrasHorizontales extends StatelessWidget {
  const BarrasHorizontales({super.key, required this.barras});

  final List<DatoBarra> barras;

  @override
  Widget build(BuildContext context) {
    final mayor = barras.fold<double>(
      0,
      (mayor, b) => math.max(mayor, b.valor),
    );

    return Column(
      spacing: 14,
      children: [
        for (final barra in barras)
          _Barra(dato: barra, largo: mayor > 0 ? barra.valor / mayor : 0),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.dato, required this.largo});

  final DatoBarra dato;

  /// De 0 a 1, contra la mayor de la lista.
  final double largo;

  static const double _grueso = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tenue = scheme.onSurfaceVariant;

    final icono = dato.icono;
    final nota = dato.nota;
    final detalle = dato.detalle;

    final barra = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 8,
          children: [
            if (icono != null) Icon(icono, size: 18, color: tenue),
            Expanded(
              child: Text(
                dato.etiqueta,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              dato.valorTexto,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (nota != null)
              SizedBox(
                width: 52,
                child: Text(
                  nota,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(color: tenue),
                ),
              ),
          ],
        ),
        // La pista es un tono del mismo color, muy claro: así se ve cuánto
        // le falta a cada barra para llegar a la mayor.
        ClipRRect(
          borderRadius: BorderRadius.circular(_grueso / 2),
          child: SizedBox(
            height: _grueso,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                // Del alto de la pista: suelta en el `Stack`, una caja sin
                // contenido mide cero y la barra no se veía.
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: largo.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(_grueso / 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return detalle == null ? barra : Tooltip(message: detalle, child: barra);
  }
}
