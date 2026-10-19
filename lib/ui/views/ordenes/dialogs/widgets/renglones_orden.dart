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
///
/// Cada renglón ocupa una sola línea a propósito: la lista vive en un diálogo
/// que no crece con ella, así que lo que mide un renglón decide cuántas
/// prendas se ven sin desplazar. Con dos líneas por renglón —el nombre arriba
/// y los controles abajo— no cabían ni tres, y una orden de mostrador trae
/// media docena. Los controles se reparten a lo ancho, que es lo que sobra.
class RenglonesOrden extends StatefulWidget {
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
  State<RenglonesOrden> createState() => _RenglonesOrdenState();
}

class _RenglonesOrdenState extends State<RenglonesOrden> {
  /// Propio y no el heredado: en escritorio nadie reparte el
  /// `PrimaryScrollController`, y la barra sólo se deja ver siempre si sabe a
  /// qué lista mira.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const _Vacia();

    // La barra se queda a la vista aunque no se esté desplazando: es lo que
    // avisa de que la orden sigue más abajo de lo que se alcanza a ver.
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.only(right: 8),
        itemCount: widget.items.length,
        separatorBuilder: (context, _) => const Divider(height: 1),
        itemBuilder: (context, indice) => _Renglon(
          item: widget.items[indice],
          onCantidad: (cantidad) => widget.onCantidad(indice, cantidad),
          onEntrega: (fecha) => widget.onEntrega(indice, fecha),
          onQuitar: () => widget.onQuitar(indice),
        ),
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

  /// Lo que el renglón necesita para caber en una línea: el nombre más los
  /// tres controles. Por debajo de eso el nombre se quedaría sin sitio, así
  /// que los controles se van a una segunda línea.
  static const double _anchoDeUnaLinea = 380;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final precio = item.precio;

    final nombre = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          precio.descripcion,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          precio.categoria,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final cantidad = _Cantidad(
      cantidad: item.cantidad,
      unidad: precio.tipoUnidad.value,
      onCambiar: onCantidad,
    );

    final importe = Text(
      precio.importePor(item.cantidad).toStringAsFixed(2),
      style: theme.textTheme.titleSmall,
    );

    final entrega = _Entrega(fecha: item.fechaEntrega, onCambiar: onEntrega);

    final quitar = _BotonChico(
      icono: Icons.close_rounded,
      tooltip: 'Quitar de la orden',
      onPressed: onQuitar,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _anchoDeUnaLinea) {
            // Dos líneas, como en una ventana angosta: el nombre y el importe
            // arriba, los controles abajo. Cuesta el doble de alto, pero en
            // este ancho la otra forma deja el nombre en nada.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: 8,
                  children: [Expanded(child: nombre), importe, quitar],
                ),
                Row(
                  spacing: 8,
                  children: [
                    cantidad,
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: entrega,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          // El nombre es lo único que se encoge: de un concepto cortado se
          // reconoce el principio, y de un importe o una fecha cortados no se
          // reconoce nada.
          return Row(
            spacing: 8,
            children: [
              Expanded(child: nombre),
              cantidad,
              // El importe y la entrega, uno debajo del otro: son las dos
              // cifras del renglón y se leen en columna al recorrer la orden.
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [importe, entrega],
              ),
              quitar,
            ],
          );
        },
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
      spacing: 2,
      children: [
        _BotonChico(
          icono: Icons.remove_circle_outline_rounded,
          tooltip: 'Una menos',
          onPressed: () => widget.onCambiar(widget.cantidad - 1),
        ),
        SizedBox(
          width: 48,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
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
        _BotonChico(
          icono: Icons.add_circle_outline_rounded,
          tooltip: 'Una más',
          onPressed: () => widget.onCambiar(widget.cantidad + 1),
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
    final theme = Theme.of(context);

    return Tooltip(
      message: 'Cambiar la fecha de entrega',
      child: TextButton.icon(
        onPressed: () => _elegir(context),
        icon: const Icon(Icons.event_rounded, size: 14),
        label: Text(fecha.formatDate),
        style: TextButton.styleFrom(
          textStyle: theme.textTheme.bodySmall,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
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

/// Un botón de icono del tamaño del renglón.
///
/// El de Material reserva cuarenta y ocho píxeles para el dedo aunque el icono
/// mida dieciocho; aquí hay tres por renglón y esa reserva es la que decidía
/// el alto de la lista entera. En el mostrador se usa con ratón.
class _BotonChico extends StatelessWidget {
  const _BotonChico({
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback onPressed;

  static const double _lado = 30;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icono),
      iconSize: 18,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: _lado, height: _lado),
    );
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
