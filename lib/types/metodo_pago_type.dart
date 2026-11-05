import 'package:flutter/material.dart';

/// Método de pago de un movimiento del historial de una orden.
enum MetodoPagoType {
  efectivo(value: 'Efectivo', icon: Icons.local_atm_rounded),
  tarjeta(value: 'Tarjeta', icon: Icons.credit_card),
  transferencia(value: 'Transferencia', icon: Icons.atm_rounded),

  /// Ya no se puede elegir —se quitó en noviembre de 2026—, pero sigue aquí
  /// para leer los pagos que se registraron con él: esos siguen diciendo
  /// "Crédito" en el historial, el ticket y los reportes.
  credito(
    value: 'Crédito',
    icon: Icons.money_off_csred_rounded,
    seleccionable: false,
  ),
  otro(value: 'Otro', icon: Icons.more_horiz);

  final String value;
  final IconData icon;

  /// Si aparece entre las opciones al cobrar y al filtrar.
  final bool seleccionable;

  const MetodoPagoType({
    required this.value,
    required this.icon,
    this.seleccionable = true,
  });

  /// Los que se ofrecen al cobrar y al filtrar, en este orden.
  static final List<MetodoPagoType> seleccionables = [
    for (final metodo in values)
      if (metodo.seleccionable) metodo,
  ];

  factory MetodoPagoType.fromString(String value) {
    return MetodoPagoType.values.firstWhere(
      (metodo) => metodo.value == value,
      orElse: () => MetodoPagoType.efectivo,
    );
  }
}
