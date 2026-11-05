import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Una columna de [GraficaColumnas].
@immutable
class ColumnaGrafica {
  const ColumnaGrafica({
    required this.etiqueta,
    required this.valor,
    required this.titulo,
    required this.detalle,
    this.resaltada = true,
  });

  /// Lo que va bajo la columna, corto: `10:00`, `Lun 2`.
  final String etiqueta;

  final double valor;

  /// El primer renglón del recuadro que sale al pasar el mouse.
  final String titulo;

  /// El segundo renglón: el importe y lo que haga falta.
  final String detalle;

  /// En el color de la empresa; si no, en gris. Así una columna puede ser
  /// "la de hoy" y las demás, el contexto.
  final bool resaltada;
}

/// Una serie de columnas sobre un eje en pesos, con el detalle de cada una
/// al pasar el mouse.
///
/// Es una sola serie, así que no lleva leyenda: el título de la tarjeta dice
/// qué se mide. Las columnas son delgadas —no llenan su espacio—, con la
/// punta redonda y la base recta sobre el eje, y la cuadrícula es una línea
/// fina que no compite con los datos.
class GraficaColumnas extends StatelessWidget {
  const GraficaColumnas({super.key, required this.columnas, this.alto = 220});

  final List<ColumnaGrafica> columnas;
  final double alto;

  /// El ancho máximo de una columna: más ancha deja de leerse como columna.
  static const double _anchoColumna = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final escala = _Escala.para(columnas.map((c) => c.valor));
    final estiloEje = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final linea = scheme.outlineVariant.withValues(alpha: 0.6);

    return SizedBox(
      height: alto,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Las columnas se adelgazan si no caben, pero no pasan del tope.
          final ancho = math.min(
            _anchoColumna,
            constraints.maxWidth / math.max(columnas.length, 1) * 0.55,
          );

          return BarChart(
            BarChartData(
              maxY: escala.maximo,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (final (indice, columna) in columnas.indexed)
                  BarChartGroupData(
                    x: indice,
                    barRods: [
                      BarChartRodData(
                        toY: columna.valor,
                        width: ancho,
                        color: columna.resaltada
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        // Transparente y de todo el alto: el mouse no tiene
                        // que atinarle a una columna chaparra.
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: escala.maximo,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: escala.intervalo,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: linea, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: scheme.outline)),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: escala.intervalo,
                    getTitlesWidget: (valor, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(pesosCortos(valor), style: estiloEje),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (valor, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        columnas[valor.toInt()].etiqueta,
                        style: estiloEje,
                      ),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                allowTouchBarBackDraw: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  maxContentWidth: 220,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (grupo, indice, barra, indiceBarra) {
                    final columna = columnas[grupo.x];

                    return BarTooltipItem(
                      '${columna.titulo}\n',
                      theme.textTheme.labelMedium!.copyWith(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: columna.detalle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// `$800`, `$1.2k`, `$15k`: lo que cabe en el eje sin apretar.
String pesosCortos(double valor) {
  if (valor < 1000) return '\$${valor.round()}';

  final miles = valor / 1000;
  final decimales = miles == miles.roundToDouble() ? 0 : 1;

  return '\$${miles.toStringAsFixed(decimales)}k';
}

/// El tope del eje y cada cuánto va una línea: números redondos, con cuatro
/// líneas, y el tope un poco arriba de la columna más alta.
class _Escala {
  const _Escala(this.maximo, this.intervalo);

  factory _Escala.para(Iterable<double> valores) {
    final mayor = valores.fold<double>(0, math.max);
    if (mayor <= 0) return const _Escala(100, 25);

    final intervalo = _redondo(mayor / 4);
    return _Escala((mayor / intervalo).ceil() * intervalo, intervalo);
  }

  final double maximo;
  final double intervalo;

  /// El número "redondo" —1, 2, 2.5 o 5 por una potencia de diez— que
  /// queda justo arriba de [valor].
  static double _redondo(double valor) {
    final potencia = math.pow(10, (math.log(valor) / math.ln10).floor());
    for (final paso in const [1, 2, 2.5, 5, 10]) {
      if (paso * potencia >= valor) return paso * potencia.toDouble();
    }
    return 10 * potencia.toDouble();
  }
}
