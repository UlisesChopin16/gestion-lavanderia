import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogo_pendiente.dart';

/// El alta de una orden de servicio.
///
/// En la aplicación anterior era la segunda pestaña del módulo —una pantalla
/// entera al lado del listado—, y aquí es un diálogo que se abre desde él: dar
/// de alta una orden es lo que se hace *desde* la lista, igual que en los
/// catálogos, y así no hay dos sitios donde pueda estar uno dentro de órdenes.
///
/// Todavía está por portar: lo que lleva dentro —buscar al cliente, elegir
/// conceptos con su cantidad, el abono y el método de pago— se migra aparte.
/// Mientras tanto avisa, para que el botón que lo abre ya esté en su sitio y
/// la pantalla no cambie cuando el contenido llegue.
///
/// Devolverá `true` cuando la orden se haya guardado, que es lo que la
/// pantalla espera para releer el listado.
class OrdenDialog extends StatelessWidget {
  const OrdenDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const DialogoPendiente(titulo: 'Nueva orden de servicio');
  }
}
