import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Lo cobrado por método de pago como barras horizontales, de la mayor a la
/// menor, con el importe y su parte del total escritos.
///
/// Barras y no un pastel: comparar largos sobre una misma base se lee bien,
/// comparar ángulos no. Y un solo color, porque lo que se compara es cuánto,
/// no quién: el nombre de cada método va escrito a su lado.
class BarrasMetodo extends StatelessWidget {
  const BarrasMetodo({super.key, required this.porMetodo, required this.total});

  final Map<MetodoPagoType, double> porMetodo;
  final double total;

  @override
  Widget build(BuildContext context) {
    final ordenados = porMetodo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mayor = ordenados.isEmpty ? 0.0 : ordenados.first.value;

    return Column(
      spacing: 14,
      children: [
        for (final MapEntry(key: metodo, value: importe) in ordenados)
          _Barra(
            metodo: metodo,
            importe: importe,
            largo: mayor > 0 ? importe / mayor : 0,
            parte: total > 0 ? importe / total : 0,
          ),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.metodo,
    required this.importe,
    required this.largo,
    required this.parte,
  });

  final MetodoPagoType metodo;
  final double importe;

  /// De 0 a 1, contra el método con más cobros: el mayor llena la pista.
  final double largo;

  /// De 0 a 1, contra el total del día.
  final double parte;

  static const double _grueso = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tenue = scheme.onSurfaceVariant;

    return Tooltip(
      message:
          '${metodo.value}: ${importe.enPesos}, '
          '${(parte * 100).toStringAsFixed(1)} % de lo cobrado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(metodo.icon, size: 18, color: tenue),
              Expanded(
                child: Text(metodo.value, style: theme.textTheme.bodyMedium),
              ),
              Text(
                importe.enPesos,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${(parte * 100).toStringAsFixed(0)} %',
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
      ),
    );
  }
}
