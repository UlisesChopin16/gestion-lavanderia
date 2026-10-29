import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/view_model/orden_detalle_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/estatus_orden_chip.dart';

/// El detalle de una orden: lo que es, lo que debe y lo que falta entregar, y
/// desde donde se cobra y se entrega.
///
/// Tiene la misma forma que el alta —la ropa a la izquierda, el dinero a la
/// derecha— porque es la continuación de lo mismo: lo que allí se armó es lo
/// que aquí se liquida.
///
/// Lo que enseña depende de lo que le queda a la orden:
///
/// * si debe, el cobro: método de pago, cuánto paga y, en efectivo, con
///   cuánto paga y su cambio;
/// * si ya está pagada, el cobro desaparece y sólo queda entregar;
/// * si se marca toda la ropa, el botón sólo deja seguir si con lo que se
///   cobra la orden queda pagada: la última prenda no sale debiendo;
/// * si está pagada y entregada —o cancelada—, un resumen sin nada que
///   tocar.
///
/// Se cierra devolviendo lo que se registró, dicho para el aviso del listado,
/// o `null` si se salió sin registrar nada.
class OrdenDetalleDialog extends ConsumerWidget {
  const OrdenDetalleDialog({super.key, required this.ordenId});

  final int ordenId;

  static const double anchoMaximo = 1040;
  static const double altoMaximo = 900;

  /// Por debajo de este ancho las dos columnas se apilan.
  static const double _corteDosColumnas = 880;

  /// Lo que separa el contenido de las orillas del diálogo.
  static const double _relleno = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ordenDetalleViewModelProvider(ordenId));
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
            _Encabezado(folio: orden?.folio, estatus: orden?.estatus),
            if (estado.mensajeError.isNotEmpty)
              _Aviso(mensaje: estado.mensajeError),
            Expanded(
              child: switch (orden) {
                _ when estado.cargando => const Center(
                  child: CircularProgressIndicator(),
                ),
                null => const _SinOrden(),
                final orden => _Cuerpo(
                  ordenId: ordenId,
                  estado: estado,
                  orden: orden,
                ),
              },
            ),
            _Pie(ordenId: ordenId, estado: estado),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.folio, required this.estatus});

  /// En `null` mientras la orden se lee.
  final String? folio;
  final EstatusOrdenType? estatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folio = this.folio;
    final estatus = this.estatus;

    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.assignment_rounded, color: scheme.onPrimary),
          Expanded(
            child: Text(
              folio == null ? 'Orden de servicio' : 'Orden $folio',
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

/// La ropa a la izquierda y el dinero a la derecha, o una debajo de la otra
/// cuando la ventana no da para dos columnas.
class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.ordenId,
    required this.estado,
    required this.orden,
  });

  final int ordenId;
  final OrdenDetalleState estado;
  final OrdenDetalleData orden;

  /// Lo que mide la lista de prendas cuando el diálogo se apila y ya no puede
  /// repartirse el alto.
  static const double _altoApilado = 280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < OrdenDetalleDialog._corteDosColumnas) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(OrdenDetalleDialog._relleno),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _Ropa(
                  ordenId: ordenId,
                  estado: estado,
                  orden: orden,
                  altoPrendas: _altoApilado,
                ),
                const Divider(height: 1),
                _Dinero(ordenId: ordenId, estado: estado, orden: orden),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(OrdenDetalleDialog._relleno),
                child: _Ropa(ordenId: ordenId, estado: estado, orden: orden),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(OrdenDetalleDialog._relleno),
                child: _Dinero(ordenId: ordenId, estado: estado, orden: orden),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// De quién es, qué se anotó y qué ropa trae.
class _Ropa extends ConsumerWidget {
  const _Ropa({
    required this.ordenId,
    required this.estado,
    required this.orden,
    this.altoPrendas,
  });

  final int ordenId;
  final OrdenDetalleState estado;
  final OrdenDetalleData orden;

  /// En `null` la lista se queda con el alto que sobre; con un valor mide
  /// eso, que es lo que necesita dentro de un desplazable.
  final double? altoPrendas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordenDetalleViewModelProvider(ordenId).notifier);
    final nota = orden.descripcion?.trim() ?? '';
    final alto = altoPrendas;

    final prendas = PrendasDetalle(
      items: orden.items,
      editable: estado.admiteMovimientos,
      seEntrega: estado.seEntrega,
      todoMarcado: estado.entregaTodo,
      onAlternar: notifier.alternarEntrega,
      onMarcarTodo: notifier.marcarTodo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        FichaCliente(
          nombre: orden.cliente,
          telefono: orden.clienteTelefono,
          correo: orden.clienteCorreo,
          recibida: orden.fechaCreacion,
        ),
        if (nota.isNotEmpty) NotaOrden(nota: nota),
        const Divider(height: 1),
        if (alto == null)
          Expanded(child: prendas)
        else
          SizedBox(height: alto, child: prendas),
      ],
    );
  }
}

/// Lo que cuesta, lo que se cobra ahora y, al final, cómo quedó.
class _Dinero extends ConsumerWidget {
  const _Dinero({
    required this.ordenId,
    required this.estado,
    required this.orden,
  });

  final int ordenId;
  final OrdenDetalleState estado;
  final OrdenDetalleData orden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordenDetalleViewModelProvider(ordenId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (estado.soloResumen)
          CierreOrden(estatus: orden.estatus, fechaCierre: orden.fechaCierre),
        CuentaDetalle(
          total: estado.total,
          pagado: estado.pagado,
          restante: estado.restante,
        ),
        if (estado.soloResumen)
          PagosOrden(historial: orden.historial)
        else if (estado.pagada)
          const OrdenYaPagada()
        else
          CobroDetalle(
            restante: estado.restante,
            abono: estado.abono,
            recibido: estado.recibido,
            cambio: estado.cambio,
            recibidoInsuficiente: estado.recibidoInsuficiente,
            metodoPago: estado.metodoPago,
            onMetodoPago: notifier.elegirMetodoPago,
            onAbono: notifier.cambiarAbono,
            onAbonarTodo: notifier.abonarTodo,
            onRecibido: notifier.cambiarRecibido,
          ),
        if (estado.faltaPagarParaEntregarTodo)
          AvisoEntregaSinPagar(
            falta: estado.restanteTras,
            onCobrarLoQueFalta: notifier.abonarTodo,
          ),
      ],
    );
  }
}

/// Los botones con los que se sale. En el resumen, sólo el de cerrar.
class _Pie extends ConsumerWidget {
  const _Pie({required this.ordenId, required this.estado});

  final int ordenId;
  final OrdenDetalleState estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sinAcciones = estado.orden == null || estado.soloResumen;

    return Container(
      padding: const EdgeInsets.all(OrdenDetalleDialog._relleno),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 12,
        children: [
          if (sinAcciones)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            )
          else ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              // Apagado mientras no haya nada que registrar, o mientras algo
              // lo impida: un efectivo que no alcanza, o toda la ropa marcada
              // sin que la orden quede pagada. El porqué se ve arriba.
              onPressed: estado.puedeRegistrar
                  ? () => _registrar(context, ref)
                  : null,
              icon: estado.guardando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(estado.etiquetaAccion),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final mensaje = await ref
        .read(ordenDetalleViewModelProvider(ordenId).notifier)
        .registrar();

    if (mensaje == null || !context.mounted) return;

    Navigator.of(context).pop(mensaje);
  }
}

/// Lo que se ve cuando la orden no se pudo leer. El porqué va en el aviso de
/// arriba.
class _SinOrden extends StatelessWidget {
  const _SinOrden();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
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
            'No se pudo abrir la orden.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Lo último que falló, a la vista y no en un diálogo encima de otro.
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
