import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';

/// La ropa de la orden en una sola lista: lo que ya salió y lo que falta.
///
/// Una sola y no dos —pendientes arriba, entregadas abajo— porque lo que se
/// compara al entregar es la orden entera contra lo que hay en el mostrador.
/// La casilla de cada renglón dice en qué punto está: marcada y apagada si ya
/// se entregó, que no se puede desmarcar porque su entrega quedó fechada en el
/// historial; libre si falta, para marcarla y entregarla ahora.
class PrendasDetalle extends StatelessWidget {
  const PrendasDetalle({
    super.key,
    required this.items,
    required this.editable,
    required this.seEntrega,
    required this.todoMarcado,
    required this.onAlternar,
    required this.onMarcarTodo,
  });

  final List<ItemOrdenData> items;

  /// Si se puede marcar ropa. En una orden cerrada o cancelada la lista sólo
  /// se mira.
  final bool editable;

  /// Si un renglón pendiente está marcado para entregarse ahora.
  final bool Function(ItemOrdenData item) seEntrega;

  /// Si está marcada toda la ropa que faltaba.
  final bool todoMarcado;

  final ValueChanged<ItemOrdenData> onAlternar;
  final ValueChanged<bool> onMarcarTodo;

  @override
  Widget build(BuildContext context) {
    final entregadas = items.where((item) => item.estaEntregado).length;
    final hayPendientes = entregadas < items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _Encabezado(
          entregadas: entregadas,
          total: items.length,
          puedeMarcar: editable && hayPendientes,
          todoMarcado: todoMarcado,
          onMarcarTodo: onMarcarTodo,
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              final item = items[indice];

              return _Renglon(
                item: item,
                marcado: item.estaEntregado || seEntrega(item),
                editable: editable && !item.estaEntregado,
                onAlternar: () => onAlternar(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.entregadas,
    required this.total,
    required this.puedeMarcar,
    required this.todoMarcado,
    required this.onMarcarTodo,
  });

  final int entregadas;
  final int total;
  final bool puedeMarcar;
  final bool todoMarcado;
  final ValueChanged<bool> onMarcarTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      spacing: 8,
      children: [
        Text('Prendas', style: theme.textTheme.titleMedium),
        Expanded(
          child: Text(
            '$entregadas de $total entregadas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (puedeMarcar)
          TextButton.icon(
            onPressed: () => onMarcarTodo(!todoMarcado),
            icon: Icon(
              todoMarcado ? Icons.remove_done_rounded : Icons.done_all_rounded,
              size: 18,
            ),
            label: Text(todoMarcado ? 'Desmarcar todo' : 'Marcar lo pendiente'),
          ),
      ],
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.item,
    required this.marcado,
    required this.editable,
    required this.onAlternar,
  });

  final ItemOrdenData item;
  final bool marcado;

  /// Si la casilla se puede tocar: sólo la ropa pendiente de una orden que
  /// todavía admite movimientos.
  final bool editable;

  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final precio = item.precio;

    return InkWell(
      // Todo el renglón marca, no sólo la casilla: en el mostrador se toca
      // el nombre de la prenda, que es lo que se está leyendo.
      onTap: editable ? onAlternar : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          spacing: 8,
          children: [
            Checkbox(
              value: marcado,
              // Sin `onChanged` la casilla se pinta apagada: es lo que dice
              // que una prenda ya entregada no se puede volver a tocar.
              onChanged: editable ? (_) => onAlternar() : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(precio.descripcion, style: theme.textTheme.titleSmall),
                  Text(
                    '${precio.categoria} · ${_cantidad(item.cantidad)} '
                    '${precio.tipoUnidad.value}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _Fecha(item: item),
                ],
              ),
            ),
            Text(
              item.importe.toStringAsFixed(2),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// `2`, no `2.0`; pero `1.5` cuando se cobra por kilo.
String _cantidad(double cantidad) => cantidad == cantidad.roundToDouble()
    ? cantidad.toStringAsFixed(0)
    : cantidad.toStringAsFixed(1);

/// Cuándo salió el renglón, o para cuándo se prometió.
///
/// Una prenda pendiente cuya fecha ya pasó se avisa en rojo: es la que el
/// cliente viene a reclamar, y la que hay que buscar primero.
class _Fecha extends StatelessWidget {
  const _Fecha({required this.item});

  final ItemOrdenData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icono, texto, color) = switch (item) {
      ItemOrdenData(estaEntregado: true, :final fechaEntregado) => (
        Icons.check_circle_rounded,
        'Entregado el ${fechaEntregado.formatDate}',
        scheme.primary,
      ),
      _ when _atrasada => (
        Icons.warning_amber_rounded,
        'Atrasada · era para el ${item.fechaEntrega.formatDate}',
        scheme.error,
      ),
      _ => (
        Icons.event_rounded,
        'Para el ${item.fechaEntrega.formatDate}',
        scheme.onSurfaceVariant,
      ),
    };

    return Row(
      spacing: 4,
      children: [
        Icon(icono, size: 14, color: color),
        Flexible(
          child: Text(
            texto,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  /// Se compara contra el principio de hoy: una prenda que se prometió para
  /// hoy todavía está a tiempo.
  bool get _atrasada {
    final ahora = DateTime.now();

    return item.fechaEntrega.isBefore(
      DateTime(ahora.year, ahora.month, ahora.day),
    );
  }
}
