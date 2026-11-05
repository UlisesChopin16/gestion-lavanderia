import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/colores_historial.dart';

/// Las cifras del corte, arriba de las gráficas: lo cobrado, cuántos cobros,
/// el efectivo que debe haber en la caja y el cambio que salió de ella.
///
/// Son números sueltos, y un número suelto se lee mejor escrito que en una
/// gráfica de una sola barra.
class IndicadoresCorte extends StatelessWidget {
  const IndicadoresCorte({super.key, required this.estadisticas});

  final EstadisticasCorte estadisticas;

  /// Por debajo de este ancho van dos por renglón.
  static const double _corteCuatro = 900;

  @override
  Widget build(BuildContext context) {
    final corte = estadisticas.corte;
    final cobros = corte.cobros.length;

    final indicadores = [
      _Indicador(
        icono: Icons.payments_rounded,
        titulo: 'Total cobrado',
        valor: corte.total.enPesos,
        principal: true,
        pie: _CambioContraAyer(cambio: estadisticas.cambioContraAyer),
      ),
      _Indicador(
        icono: Icons.receipt_long_rounded,
        titulo: 'Cobros',
        valor: '$cobros',
        pie: _Nota(
          cobros == 0
              ? 'Ninguna orden'
              : 'En ${corte.ordenes} '
                    '${corte.ordenes == 1 ? 'orden' : 'órdenes'}',
        ),
      ),
      _Indicador(
        icono: Icons.point_of_sale_rounded,
        titulo: 'Debe haber en caja',
        valor: corte.efectivoCobrado.enPesos,
        pie: const _Nota('Más el fondo con el que se abrió'),
      ),
      _Indicador(
        icono: Icons.currency_exchange_rounded,
        titulo: 'Cambio dado',
        valor: corte.cambioEntregado.enPesos,
        pie: _Nota(
          'De ${corte.efectivoRecibido.enPesos} que dieron los clientes',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final porRenglon = constraints.maxWidth >= _corteCuatro ? 4 : 2;
        const espacio = 12.0;
        final ancho =
            (constraints.maxWidth - espacio * (porRenglon - 1)) / porRenglon;

        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final indicador in indicadores)
              SizedBox(width: ancho, child: indicador),
          ],
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.pie,
    this.principal = false,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final Widget pie;

  /// La cifra por la que se abre el corte: va más grande y sobre el color de
  /// la empresa.
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borde = scheme.bordeTarjeta;
    final tenue = principal
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: principal ? scheme.primaryContainer : scheme.fondoTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: principal || borde == null ? null : Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(icono, size: 18, color: tenue),
              Expanded(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: tenue),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style:
                  (principal
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: principal ? scheme.onPrimaryContainer : null,
                      ),
            ),
          ),
          DefaultTextStyle.merge(
            style: TextStyle(color: tenue),
            child: pie,
          ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: DefaultTextStyle.of(context).style.color),
    );
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
    if (cambio == null) return const _Nota('Sin cobros el día anterior');

    final porcentaje = (cambio.abs() * 100).toStringAsFixed(0);
    if (porcentaje == '0') return const _Nota('Igual que el día anterior');

    final sube = cambio > 0;

    return Row(
      spacing: 4,
      children: [
        Icon(
          sube ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 16,
        ),
        Expanded(
          child: _Nota(
            '$porcentaje % ${sube ? 'más' : 'menos'} que el día anterior',
          ),
        ),
      ],
    );
  }
}
