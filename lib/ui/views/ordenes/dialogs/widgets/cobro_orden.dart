import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';

/// Lo que se cobra al dejar la ropa: el total, con qué se paga y cuánto se
/// adelanta.
///
/// Las tres cifras van juntas y en el mismo bloque porque se leen juntas: lo
/// que suma la ropa, lo que el cliente entrega ahora y lo que queda a deber.
/// La resta se calcula sola, para que nadie tenga que hacer la cuenta en el
/// mostrador.
///
/// Los dos atajos del adelanto cubren lo que pasa casi siempre: o no deja
/// nada, o paga completo. Cualquier otra cantidad se escribe.
class CobroOrden extends StatefulWidget {
  const CobroOrden({
    super.key,
    required this.total,
    required this.abono,
    required this.metodoPago,
    required this.entregaEstimada,
    required this.onAbono,
    required this.onMetodoPago,
  });

  final double total;
  final double abono;
  final MetodoPagoType metodoPago;

  /// Cuándo estaría lista la orden entera, o `null` si todavía no hay ropa.
  final DateTime? entregaEstimada;

  final ValueChanged<double> onAbono;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  @override
  State<CobroOrden> createState() => _CobroOrdenState();
}

class _CobroOrdenState extends State<CobroOrden> {
  late final TextEditingController _controller = TextEditingController(
    text: _texto,
  );

  String get _texto => widget.abono.toStringAsFixed(2);

  double get _resta => widget.total - widget.abono;

  @override
  void didUpdateWidget(CobroOrden oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se compara el número y no el texto: "50" y "50.00" son el mismo abono,
    // y reescribir el campo a media captura movería el cursor al final. Lo
    // que sí se repone es un cambio que viene de fuera —un atajo, o el
    // recorte al quitar ropa—, porque entonces el número ya no es el escrito.
    final escrito = double.tryParse(_controller.text);
    if (escrito != widget.abono) _controller.text = _texto;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entrega = widget.entregaEstimada;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _Cifra(
            etiqueta: 'Total',
            importe: widget.total,
            estilo: theme.textTheme.headlineSmall,
          ),
          if (entrega != null)
            Row(
              spacing: 6,
              children: [
                Icon(Icons.event_available_rounded, size: 16),
                Text(
                  'Lista el ${entrega.formatDate}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          const Divider(height: 1),
          DropdownMenuBase<MetodoPagoType>(
            label: 'Método de pago',
            value: widget.metodoPago,
            leadingIcon: Icon(widget.metodoPago.icon),
            items: [
              for (final metodo in MetodoPagoType.values)
                DropdownMenuEntry<MetodoPagoType>(
                  value: metodo,
                  label: metodo.value,
                  leadingIcon: Icon(metodo.icon),
                ),
            ],
            onChanged: (metodo) =>
                widget.onMetodoPago(metodo ?? widget.metodoPago),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Adelanto',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  onChanged: (texto) =>
                      widget.onAbono(double.tryParse(texto) ?? 0),
                ),
              ),
              _Atajo(
                texto: 'Nada',
                activo: widget.abono == 0,
                onPressed: () => widget.onAbono(0),
              ),
              _Atajo(
                texto: 'Todo',
                activo: widget.abono == widget.total && widget.total > 0,
                onPressed: () => widget.onAbono(widget.total),
              ),
            ],
          ),
          _Cifra(
            etiqueta: _resta > 0 ? 'Queda a deber' : 'Pagada',
            importe: _resta,
            estilo: theme.textTheme.titleMedium?.copyWith(
              color: _resta > 0 ? scheme.error : scheme.primary,
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
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelLarge),
        Text(importe.toStringAsFixed(2), style: estilo),
      ],
    );
  }
}

/// Un atajo del adelanto, marcado cuando el importe ya es ese.
class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.texto,
    required this.activo,
    required this.onPressed,
  });

  final String texto;
  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (activo) {
      return FilledButton(onPressed: onPressed, child: Text(texto));
    }

    return OutlinedButton(onPressed: onPressed, child: Text(texto));
  }
}
