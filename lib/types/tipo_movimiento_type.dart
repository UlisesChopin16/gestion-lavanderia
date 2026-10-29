import 'package:flutter/material.dart';

/// Qué pasó en un movimiento del historial de una orden.
///
/// No se guarda: se deduce de lo que el movimiento cobró y entregó, y de si
/// fue el primero. Vive aquí, con su icono y su color, para que el resumen del
/// detalle y el historial llamen igual a lo mismo: el cobro del alta es un
/// adelanto en las dos pantallas, o en ninguna.
///
/// El color sigue lo que se movió y no lo bien que salió: verde lo que entró
/// de dinero, azul la ropa que salió, y los dos juntos a medio camino.
enum TipoMovimientoType {
  /// El primer movimiento de una orden que nació sin adelanto: no cobra ni
  /// entrega, pero es el que fecha el alta.
  alta(
    titulo: 'Alta de la orden',
    icon: Icons.post_add_rounded,
    color: Colors.blueGrey,
  ),

  /// Lo que se cobró al recibir la ropa.
  adelanto(
    titulo: 'Adelanto',
    icon: Icons.savings_rounded,
    color: Colors.green,
  ),
  pago(titulo: 'Pago', icon: Icons.payments_rounded, color: Colors.green),
  entrega(
    titulo: 'Entrega',
    icon: Icons.inventory_2_rounded,
    color: Colors.blue,
  ),
  pagoYEntrega(
    titulo: 'Pago y entrega',
    icon: Icons.local_shipping_rounded,
    color: Colors.teal,
  );

  final String titulo;
  final IconData icon;
  final Color color;

  const TipoMovimientoType({
    required this.titulo,
    required this.icon,
    required this.color,
  });

  bool get cobra => this == adelanto || this == pago || this == pagoYEntrega;
}
