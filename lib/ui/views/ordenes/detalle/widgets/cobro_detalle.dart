import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';

/// Lo que se cobra ahora: con qué paga, cuánto paga y, si es en efectivo, con
/// cuánto paga y cuánto se le devuelve.
///
/// "Cuánto paga" y "con cuánto paga" son dos números distintos, y por eso son
/// dos campos: el cliente da un billete de quinientos para pagar trescientos.
/// Lo que se abona a la orden es lo primero; lo segundo saca el cambio y queda
/// guardado en el movimiento, para que el historial diga con cuánto pagó.
///
/// Los campos de importe nacen vacíos con la pista `0.00`, igual que el
/// adelanto del alta: un cero escrito parece un importe capturado.
class CobroDetalle extends StatelessWidget {
  const CobroDetalle({
    super.key,
    required this.restante,
    required this.abono,
    required this.recibido,
    required this.cambio,
    required this.recibidoInsuficiente,
    required this.metodoPago,
    required this.onMetodoPago,
    required this.onAbono,
    required this.onAbonarTodo,
    required this.onRecibido,
  });

  final double restante;
  final double abono;
  final double recibido;
  final double cambio;

  /// Si lo que entrega el cliente no alcanza para lo que dice que paga.
  final bool recibidoInsuficiente;

  final MetodoPagoType metodoPago;
  final ValueChanged<MetodoPagoType> onMetodoPago;
  final ValueChanged<double> onAbono;
  final VoidCallback onAbonarTodo;
  final ValueChanged<double> onRecibido;

  @override
  Widget build(BuildContext context) {
    final efectivo = metodoPago == MetodoPagoType.efectivo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text('Cobrar', style: Theme.of(context).textTheme.titleMedium),
        _MetodoPago(metodoPago: metodoPago, onMetodoPago: onMetodoPago),
        CampoImporte(
          etiqueta: 'A pagar',
          valor: abono,
          onCambio: onAbono,
          ayuda: 'Restan ${restante.toStringAsFixed(2)}',
          // El atajo va dentro del campo y no al lado: un botón junto a un
          // campo nunca mide lo mismo de alto, y aquí no hace falta que lo
          // haga.
          sufijo: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: onAbonarTodo,
              child: const Text('Todo'),
            ),
          ),
        ),
        if (efectivo) ...[
          CampoImporte(
            etiqueta: 'Recibe',
            valor: recibido,
            onCambio: onRecibido,
            ayuda: 'Con cuánto paga el cliente',
            error: recibidoInsuficiente
                ? 'No alcanza para lo que va a pagar'
                : null,
          ),
          if (recibido > 0 && !recibidoInsuficiente) _Cambio(cambio: cambio),
        ],
      ],
    );
  }
}

class _MetodoPago extends StatelessWidget {
  const _MetodoPago({required this.metodoPago, required this.onMetodoPago});

  final MetodoPagoType metodoPago;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<MetodoPagoType>(
      label: 'Método de pago',
      value: metodoPago,
      leadingIcon: Icon(metodoPago.icon),
      items: [
        for (final metodo in MetodoPagoType.values)
          DropdownMenuEntry<MetodoPagoType>(
            value: metodo,
            label: metodo.value,
            leadingIcon: Icon(metodo.icon),
          ),
      ],
      onChanged: (metodo) => onMetodoPago(metodo ?? metodoPago),
    );
  }
}

/// Lo que hay que devolverle al cliente.
class _Cambio extends StatelessWidget {
  const _Cambio({required this.cambio});

  final double cambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Cambio',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            cambio.toStringAsFixed(2),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
