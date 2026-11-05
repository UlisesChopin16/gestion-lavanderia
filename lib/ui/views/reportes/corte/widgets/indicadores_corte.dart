import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/indicador_estadistica.dart';

/// Las cifras del corte, arriba de las gráficas: lo cobrado, cuántos cobros,
/// el efectivo que debe haber en la caja y el cambio que salió de ella.
class IndicadoresCorte extends StatelessWidget {
  const IndicadoresCorte({super.key, required this.estadisticas});

  final EstadisticasCorte estadisticas;

  @override
  Widget build(BuildContext context) {
    final corte = estadisticas.corte;
    final cobros = corte.cobros.length;

    final indicadores = [
      IndicadorEstadistica(
        icono: Icons.payments_rounded,
        titulo: 'Total cobrado',
        valor: corte.total.enPesos,
        principal: true,
        pie: _CambioContraAyer(cambio: estadisticas.cambioContraAyer),
      ),
      IndicadorEstadistica(
        icono: Icons.receipt_long_rounded,
        titulo: 'Cobros',
        valor: '$cobros',
        pie: NotaIndicador(
          cobros == 0
              ? 'Ninguna orden'
              : 'En ${corte.ordenes} '
                    '${corte.ordenes == 1 ? 'orden' : 'órdenes'}',
        ),
      ),
      IndicadorEstadistica(
        icono: Icons.point_of_sale_rounded,
        titulo: 'Debe haber en caja',
        valor: corte.efectivoCobrado.enPesos,
        pie: const NotaIndicador('Más el fondo con el que se abrió'),
      ),
      IndicadorEstadistica(
        icono: Icons.currency_exchange_rounded,
        titulo: 'Cambio dado',
        valor: corte.cambioEntregado.enPesos,
        pie: NotaIndicador(
          'De ${corte.efectivoRecibido.enPesos} que dieron los clientes',
        ),
      ),
    ];

    return FilaIndicadores(indicadores: indicadores);
  }
}

/// `▲ 12 % contra el día anterior`. La flecha dice hacia dónde fue; el texto,
/// cuánto: el color no carga el significado solo.
class _CambioContraAyer extends StatelessWidget {
  const _CambioContraAyer({required this.cambio});

  /// Fracción: `0.12` es 12 % más. En `null`, el día anterior no se cobró.
  final double? cambio;

  @override
  Widget build(BuildContext context) {
    final cambio = this.cambio;
    if (cambio == null) {
      return const NotaIndicador('Sin cobros el día anterior');
    }

    final porcentaje = (cambio.abs() * 100).toStringAsFixed(0);
    if (porcentaje == '0') {
      return const NotaIndicador('Igual que el día anterior');
    }

    final sube = cambio > 0;

    return Row(
      spacing: 4,
      children: [
        Icon(
          sube ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 16,
        ),
        Expanded(
          child: NotaIndicador(
            '$porcentaje % ${sube ? 'más' : 'menos'} que el día anterior',
          ),
        ),
      ],
    );
  }
}
