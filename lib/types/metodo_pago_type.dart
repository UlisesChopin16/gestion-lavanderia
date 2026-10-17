import 'package:flutter/material.dart';

/// Método de pago de un movimiento del historial de una orden.
enum MetodoPagoType {
  efectivo(value: 'Efectivo', icon: Icons.local_atm_rounded),
  tarjeta(value: 'Tarjeta', icon: Icons.credit_card),
  transferencia(value: 'Transferencia', icon: Icons.atm_rounded),
  credito(value: 'Crédito', icon: Icons.money_off_csred_rounded),
  otro(value: 'Otro', icon: Icons.more_horiz);

  final String value;
  final IconData icon;

  const MetodoPagoType({required this.value, required this.icon});

  factory MetodoPagoType.fromString(String value) {
    return MetodoPagoType.values.firstWhere(
      (metodo) => metodo.value == value,
      orElse: () => MetodoPagoType.efectivo,
    );
  }
}
