import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';

/// Las tres cifras de la orden: lo que cuesta, lo que ya se pagó y lo que
/// queda a deber.
class CuentaDetalle extends StatelessWidget {
  const CuentaDetalle({
    super.key,
    required this.total,
    required this.pagado,
    required this.restante,
  });

  final double total;
  final double pagado;
  final double restante;

  /// El mismo margen con el que la base da una orden por saldada.
  static const double _margen = 0.005;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final debe = restante > _margen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          _Cifra(
            etiqueta: 'Total',
            importe: total,
            estilo: theme.textTheme.titleMedium,
          ),
          _Cifra(
            etiqueta: 'Pagado',
            importe: pagado,
            estilo: theme.textTheme.titleMedium,
          ),
          const Divider(height: 1),
          _Cifra(
            // La etiqueta dice el estado y el color lo repite: una orden que
            // debe se reconoce sin leer la cifra.
            etiqueta: debe ? 'Queda a deber' : 'Pagada',
            importe: debe ? restante : 0,
            estilo: theme.textTheme.headlineSmall?.copyWith(
              color: debe ? scheme.error : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.importe,
    required this.estilo,
  });

  final String etiqueta;
  final double importe;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelLarge),
        Text(importe.toStringAsFixed(2), style: estilo),
      ],
    );
  }
}

/// Cómo terminó la orden: pagada y entregada, o cancelada.
///
/// Va arriba del resumen para que lo primero que se lea de una orden que ya
/// no tiene nada pendiente sea eso: que no tiene nada pendiente.
class CierreOrden extends StatelessWidget {
  const CierreOrden({
    super.key,
    required this.estatus,
    required this.fechaCierre,
  });

  final EstatusOrdenType estatus;
  final DateTime? fechaCierre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelada = estatus == EstatusOrdenType.cancelada;
    final cierre = fechaCierre;
    final color = estatus.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(estatus.icon, color: color, size: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  cancelada ? 'Orden cancelada' : 'Pagada y entregada',
                  style: theme.textTheme.titleMedium,
                ),
                if (cierre != null)
                  Text(
                    'Se cerró el ${cierre.formatFullDate}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Por qué el botón no deja entregar: se marcó toda la ropa y la orden no
/// queda pagada.
///
/// Trae el atajo para arreglarlo en el mismo sitio en que se avisa: lo normal
/// es que el cliente pague lo que falta en ese momento, no que se desmarque
/// una prenda.
class AvisoEntregaSinPagar extends StatelessWidget {
  const AvisoEntregaSinPagar({
    super.key,
    required this.falta,
    required this.onCobrarLoQueFalta,
  });

  /// Lo que todavía quedaría a deber con lo que se está cobrando.
  final double falta;

  final VoidCallback onCobrarLoQueFalta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(Icons.lock_outline_rounded, color: scheme.onErrorContainer),
              Expanded(
                child: Text(
                  'Para entregar toda la ropa la orden tiene que quedar '
                  'pagada. Faltan ${falta.toStringAsFixed(2)}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCobrarLoQueFalta,
              child: const Text('Cobrar lo que falta'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve en lugar del cobro cuando ya no hay nada que cobrar.
class OrdenYaPagada extends StatelessWidget {
  const OrdenYaPagada({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      spacing: 10,
      children: [
        Icon(Icons.verified_rounded, color: scheme.primary),
        Expanded(
          child: Text(
            'La orden ya está pagada: sólo falta entregar la ropa.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
