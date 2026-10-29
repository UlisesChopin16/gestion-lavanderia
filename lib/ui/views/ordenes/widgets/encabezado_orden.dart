import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/estatus_orden_chip.dart';

/// La franja de arriba de los diálogos de una orden: qué se está viendo, de
/// qué orden, en qué estatus está y el botón de cerrar.
///
/// La comparten el detalle y el historial para que se reconozcan como dos
/// vistas de la misma orden, y no como dos pantallas distintas.
class EncabezadoOrden extends StatelessWidget {
  const EncabezadoOrden({
    super.key,
    required this.titulo,
    required this.icono,
    required this.estatus,
  });

  final String titulo;
  final IconData icono;

  /// En `null` mientras la orden se lee.
  final EstatusOrdenType? estatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estatus = this.estatus;

    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        spacing: 12,
        children: [
          Icon(icono, color: scheme.onPrimary),
          Expanded(
            child: Text(
              titulo,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
          if (estatus != null)
            // Sobre el fondo de la superficie y no sobre el primario: la
            // etiqueta trae su color en el contorno, y sobre azul se perdía.
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: EstatusOrdenChip(estatus: estatus),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: scheme.onPrimary),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

/// Lo último que falló, a la vista y no en un diálogo encima de otro.
class AvisoErrorOrden extends StatelessWidget {
  const AvisoErrorOrden({super.key, required this.mensaje});

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
