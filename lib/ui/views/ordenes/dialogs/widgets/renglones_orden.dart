import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// La ropa que lleva la orden, con lo que se puede cambiar de cada renglón:
/// cuánta, para cuándo y si se queda.
///
/// La fecha sale calculada de los días que pide el concepto, y se puede
/// correr renglón por renglón: una prenda que el cliente necesita antes no
/// obliga a cambiar el catálogo.
class RenglonesOrden extends StatelessWidget {
  const RenglonesOrden({
    super.key,
    required this.items,
    required this.onCantidad,
    required this.onEntrega,
    required this.onQuitar,
  });

  final List<ItemOrdenData> items;

  /// La cantidad nueva de un renglón. Por debajo de una unidad el renglón se
  /// quita, que es lo que significa bajar de uno.
  final void Function(int indice, double cantidad) onCantidad;

  final void Function(int indice, DateTime fecha) onEntrega;
  final ValueChanged<int> onQuitar;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Vacia();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, _) => const Divider(height: 1),
      itemBuilder: (context, indice) => _Renglon(
        item: items[indice],
        onCantidad: (cantidad) => onCantidad(indice, cantidad),
        onEntrega: (fecha) => onEntrega(indice, fecha),
        onQuitar: () => onQuitar(indice),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.item,
    required this.onCantidad,
    required this.onEntrega,
    required this.onQuitar,
  });

  final ItemOrdenData item;
  final ValueChanged<double> onCantidad;
  final ValueChanged<DateTime> onEntrega;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final precio = item.precio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(precio.descripcion, style: theme.textTheme.titleSmall),
                    Text(
                      precio.categoria,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                precio.importePor(item.cantidad).toStringAsFixed(2),
                style: theme.textTheme.titleSmall,
              ),
              IconButton(
                onPressed: onQuitar,
                icon: const Icon(Icons.close_rounded),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: 'Quitar de la orden',
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              _Cantidad(
                cantidad: item.cantidad,
                unidad: precio.tipoUnidad.value,
                onCambiar: onCantidad,
              ),
              Expanded(
                child: _Entrega(fecha: item.fechaEntrega, onCambiar: onEntrega),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cuántas unidades van de un concepto.
///
/// Los botones son para lo común —una prenda más, una menos— y el campo del
/// medio para lo que no se cuenta de uno en uno: tres kilos y medio de ropa
/// por peso se escriben, no se pulsan siete veces.
class _Cantidad extends StatefulWidget {
  const _Cantidad({
    required this.cantidad,
    required this.unidad,
    required this.onCambiar,
  });

  final double cantidad;
  final String unidad;
  final ValueChanged<double> onCambiar;

  @override
  State<_Cantidad> createState() => _CantidadState();
}

class _CantidadState extends State<_Cantidad> {
  late final TextEditingController _controller = TextEditingController(
    text: _texto,
  );

  String get _texto => widget.cantidad == widget.cantidad.roundToDouble()
      ? widget.cantidad.toStringAsFixed(0)
      : widget.cantidad.toString();

  @override
  void didUpdateWidget(_Cantidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se compara el número y no el texto: así "1." a medio escribir no se
    // reescribe sola mientras se teclea, y un cambio que viene de los botones
    // sí se refleja.
    final escrita = double.tryParse(_controller.text);
    if (escrita != widget.cantidad) _controller.text = _texto;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => widget.onCambiar(widget.cantidad - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: 'Una menos',
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (texto) {
              final cantidad = double.tryParse(texto);
              // Un campo a medio escribir —vacío, o sólo el punto— no cambia
              // nada todavía: quitarlo del carrito a media captura sería
              // perder el renglón por teclear.
              if (cantidad != null && cantidad > 0) widget.onCambiar(cantidad);
            },
          ),
        ),
        IconButton(
          onPressed: () => widget.onCambiar(widget.cantidad + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: 'Una más',
        ),
        Text(widget.unidad, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Para cuándo se promete el renglón.
class _Entrega extends StatelessWidget {
  const _Entrega({required this.fecha, required this.onCambiar});

  final DateTime fecha;
  final ValueChanged<DateTime> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => _elegir(context),
        icon: const Icon(Icons.event_rounded, size: 18),
        label: Text('Entrega ${fecha.formatDate}'),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateTime.now();

    final elegida = await showDatePicker(
      context: context,
      initialDate: fecha,
      // Una entrega en el pasado no es una promesa que se pueda cumplir.
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 1, hoy.month, hoy.day),
      helpText: 'Fecha de entrega',
    );

    if (elegida != null) onCambiar(elegida);
  }
}

class _Vacia extends StatelessWidget {
  const _Vacia();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(
              IconsManager.clotheIcon,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            Text(
              'Toca un concepto para agregarlo a la orden.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
