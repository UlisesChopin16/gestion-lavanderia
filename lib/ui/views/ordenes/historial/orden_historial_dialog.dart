import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/view_model/orden_historial_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/encabezado_orden.dart';

/// El historial de una orden: cómo llegó a donde está.
///
/// Lo más reciente va arriba: primero en qué va —cuánto se ha pagado, cuánta
/// ropa ha salido—, después lo que falta o cómo se cerró, y debajo cada visita
/// del cliente, de la última al alta, con lo que pagó, con qué y lo que se
/// llevó.
///
/// Sólo se mira: cobrar y entregar se hacen desde el detalle, que es donde
/// están las reglas que lo cuidan.
class OrdenHistorialDialog extends ConsumerWidget {
  const OrdenHistorialDialog({super.key, required this.ordenId});

  final int ordenId;

  /// Más angosto que el detalle: es una sola columna que se lee hacia abajo,
  /// y a lo ancho los renglones quedarían con el importe lejos de su nombre.
  static const double anchoMaximo = 720;
  static const double altoMaximo = 900;

  /// Lo que separa el contenido de las orillas del diálogo.
  static const double _relleno = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ordenHistorialViewModelProvider(ordenId));
    final orden = estado.orden;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: anchoMaximo,
          maxHeight: altoMaximo,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoOrden(
              titulo: orden == null
                  ? 'Historial de la orden'
                  : 'Historial · Orden ${orden.folio}',
              icono: Icons.history_rounded,
              estatus: orden?.estatus,
            ),
            if (estado.mensajeError.isNotEmpty)
              AvisoErrorOrden(mensaje: estado.mensajeError),
            Flexible(
              child: switch (orden) {
                _ when estado.cargando => const _Cargando(),
                null => const _SinOrden(),
                final orden => SingleChildScrollView(
                  padding: const EdgeInsets.all(_relleno),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      ResumenHistorial(orden: orden),
                      _Movimientos(estado: estado, orden: orden),
                    ],
                  ),
                ),
              },
            ),
            const _Pie(),
          ],
        ),
      ),
    );
  }
}

/// El título de la línea de tiempo y la línea.
class _Movimientos extends StatelessWidget {
  const _Movimientos({required this.estado, required this.orden});

  final OrdenHistorialState estado;
  final OrdenDetalleData orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuantos = estado.movimientos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            Text('Movimientos', style: theme.textTheme.titleMedium),
            Text(
              cuantos == 1 ? '1 registro' : '$cuantos registros',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        LineaDeTiempo(dias: estado.dias, orden: orden),
      ],
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(OrdenHistorialDialog._relleno),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ),
    );
  }
}

/// Con alto propio: el diálogo se ajusta a lo que trae, y un indicador solo
/// lo dejaría del tamaño de un botón.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Lo que se ve cuando la orden no se pudo leer. El porqué va en el aviso de
/// arriba.
class _SinOrden extends StatelessWidget {
  const _SinOrden();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            Text(
              'No se pudo abrir el historial.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
