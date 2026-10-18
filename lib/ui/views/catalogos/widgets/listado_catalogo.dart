import 'package:flutter/material.dart';

/// La tarjeta de un listado del módulo de catálogos.
///
/// Ocupa todo el espacio que le deja la barra de pestañas, a lo ancho y a lo
/// alto: un listado no se sabe de antemano cuánto mide, y una tarjeta centrada
/// de ancho fijo —como estaba antes— dejaba media pantalla vacía a los lados
/// mientras la tabla se apretaba en el centro.
///
/// El desplazamiento va por dentro: así los filtros y el pie de paginación
/// pertenecen a la tarjeta y no se quedan flotando sobre el fondo de la
/// pantalla cuando la lista es larga.
class ListadoCatalogo extends StatelessWidget {
  const ListadoCatalogo({
    super.key,
    required this.child,
    this.mensajeError = '',
  });

  final Widget child;

  /// Lo último que falló al leer o escribir. Vacío si no hay nada que avisar.
  final String mensajeError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mensajeError.isNotEmpty) _Aviso(mensaje: mensajeError),
            Expanded(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Lo último que falló, a la vista y no en un diálogo que se cierra.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
