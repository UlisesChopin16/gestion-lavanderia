import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';

/// Cada cobro del día, por folio: lo que se revisa cuando la caja no cuadra.
/// En efectivo, con cuánto pagó el cliente y su cambio.
///
/// Es también la forma de leer el corte sin las gráficas: todo lo que ellas
/// dibujan sale de estos renglones.
class TablaCobros extends StatelessWidget {
  const TablaCobros({super.key, required this.cobros});

  final List<CobroCorte> cobros;

  /// Por debajo de este ancho la tabla se desplaza de lado en lugar de
  /// apretar las columnas.
  static const double _anchoMinimo = 760;

  static const _alineaciones = [
    TextAlign.left,
    TextAlign.center,
    TextAlign.left,
    TextAlign.left,
    TextAlign.right,
    TextAlign.right,
    TextAlign.right,
  ];

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
                textAlign: _alineaciones[indice],
                style: estilo,
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = math.max(constraints.maxWidth, _anchoMinimo);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(0.7),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.1),
                5: FlexColumnWidth(1.1),
                6: FlexColumnWidth(1),
              },
              children: [
                renglon(CorteCaja.columnas, estilo: estiloEncabezado),
                for (final (indice, cobro) in cobros.indexed)
                  renglon(
                    [
                      cobro.folio,
                      cobro.fecha.formatTime,
                      cobro.cliente,
                      cobro.metodo.value,
                      cobro.monto.enPesos,
                      cobro.entregado?.enPesos ?? '—',
                      cobro.cambio?.enPesos ?? '—',
                    ],
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
