import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/ordenes/movimiento_data.dart';

/// Lo que pasó con la orden, del movimiento más reciente al más antiguo.
///
/// Sólo va en el resumen: mientras la orden sigue abierta lo que importa es
/// lo que falta, y los movimientos pasados distraen de eso.
class PagosOrden extends StatelessWidget {
  const PagosOrden({super.key, required this.historial});

  final List<MovimientoData> historial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text('Movimientos', style: Theme.of(context).textTheme.titleMedium),
        for (final (indice, movimiento) in historial.indexed) ...[
          if (indice > 0) const Divider(height: 1),
          // El historial va del más reciente al más antiguo: el último es el
          // del alta.
          _Movimiento(
            movimiento: movimiento,
            esAlta: indice == historial.length - 1,
          ),
        ],
      ],
    );
  }
}

class _Movimiento extends StatelessWidget {
  const _Movimiento({required this.movimiento, required this.esAlta});

  final MovimientoData movimiento;

  /// Si es el movimiento con el que nació la orden: su cobro es el adelanto.
  final bool esAlta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entregados = movimiento.entregados.length;
    final conceptos = entregados == 1 ? '1 concepto' : '$entregados conceptos';
    final metodo = movimiento.metodoPago;

    final (icono, descripcion) = switch (movimiento) {
      MovimientoData(huboAbono: true, huboEntrega: true) => (
        Icons.local_shipping_rounded,
        'Pago con ${metodo.value} y entrega de $conceptos',
      ),
      MovimientoData(huboAbono: true) when esAlta => (
        metodo.icon,
        'Adelanto con ${metodo.value}',
      ),
      MovimientoData(huboAbono: true) => (
        metodo.icon,
        'Pago con ${metodo.value}',
      ),
      MovimientoData(huboEntrega: true) => (
        Icons.inventory_2_outlined,
        'Entrega de $conceptos',
      ),
      // El primer movimiento de una orden que nació sin adelanto: no cobra
      // ni entrega, pero es el que fecha el alta.
      _ => (Icons.post_add_rounded, 'Alta de la orden'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          Icon(icono, size: 20, color: scheme.onSurfaceVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(descripcion, style: theme.textTheme.bodyMedium),
                Text(
                  movimiento.fecha.formatFullDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (movimiento case MovimientoData(
                  :final double recibido,
                  :final double cambio,
                ))
                  _Efectivo(recibido: recibido, cambio: cambio),
              ],
            ),
          ),
          if (movimiento.huboAbono)
            Text(
              movimiento.monto.toStringAsFixed(2),
              style: theme.textTheme.titleSmall,
            ),
        ],
      ),
    );
  }
}

/// Con cuánto pagó el cliente en efectivo y cuánto se le devolvió.
///
/// Sin cambio sólo se dice que pagó justo: "Recibió 330.00 · cambio 0.00" es
/// leer dos números para enterarse de que no pasó nada.
class _Efectivo extends StatelessWidget {
  const _Efectivo({required this.recibido, required this.cambio});

  final double recibido;
  final double cambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texto = cambio > 0.005
        ? 'Recibió ${recibido.toStringAsFixed(2)} · '
              'cambio ${cambio.toStringAsFixed(2)}'
        : 'Pagó justo';

    return Text(
      texto,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
