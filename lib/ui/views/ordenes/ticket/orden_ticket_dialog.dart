import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/view_model/orden_ticket_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/encabezado_orden.dart';

/// El ticket de una orden: la vista previa y lo que se puede hacer con él,
/// imprimirlo, descargarlo o enviarlo por correo.
///
/// La vista previa ocupa casi todo: es lo que se viene a ver. Las acciones
/// van abajo, con la principal —imprimir, que es lo que sigue en el
/// mostrador— rellena, como en el resto de los diálogos.
class OrdenTicketDialog extends ConsumerWidget {
  const OrdenTicketDialog({super.key, required this.ordenId});

  final int ordenId;

  static const double anchoMaximo = 560;
  static const double altoMaximo = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ordenTicketViewModelProvider(ordenId));
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
                  ? 'Ticket de la orden'
                  : 'Ticket · Orden ${orden.folio}',
              icono: Icons.receipt_long_rounded,
              estatus: orden?.estatus,
            ),
            if (estado.mensajeError.isNotEmpty)
              AvisoErrorOrden(mensaje: estado.mensajeError),
            Flexible(
              child: VistaPreviaTicket(
                paginas: estado.paginas,
                cargando: estado.cargando,
              ),
            ),
            _Pie(ordenId: ordenId, estado: estado),
          ],
        ),
      ),
    );
  }
}

/// Cerrar, enviar por correo, descargar e imprimir.
class _Pie extends ConsumerWidget {
  const _Pie({required this.ordenId, required this.estado});

  final int ordenId;
  final OrdenTicketState estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final disponible = estado.listo && !estado.ocupado;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // En Wrap y no en Row: en una ventana angosta los botones no caben en
      // un renglón, y es mejor que bajen a que se desborden.
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          OutlinedButton.icon(
            onPressed: disponible ? () => _enviar(context) : null,
            icon: const Icon(Icons.forward_to_inbox_rounded),
            label: const Text('Enviar por correo'),
          ),
          OutlinedButton.icon(
            onPressed: disponible ? () => _descargar(context, ref) : null,
            icon: estado.guardando
                ? const _Girando()
                : const Icon(Icons.download_rounded),
            label: const Text('Descargar PDF'),
          ),
          FilledButton.icon(
            onPressed: disponible
                ? ref
                      .read(ordenTicketViewModelProvider(ordenId).notifier)
                      .imprimir
                : null,
            icon: estado.imprimiendo
                ? const _Girando()
                : const Icon(Icons.print_rounded),
            label: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }

  Future<void> _descargar(BuildContext context, WidgetRef ref) async {
    final mensaje = await ref
        .read(ordenTicketViewModelProvider(ordenId).notifier)
        .descargar();

    if (mensaje == null || !context.mounted) return;

    await context.showSuccessDialog(mensaje);
  }

  Future<void> _enviar(BuildContext context) async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (context) => EnviarTicketDialog(ordenId: ordenId),
    );

    if (mensaje == null || !context.mounted) return;

    await context.showSuccessDialog(mensaje);
  }
}

/// El indicador que toma el lugar del icono mientras el botón trabaja.
class _Girando extends StatelessWidget {
  const _Girando();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
