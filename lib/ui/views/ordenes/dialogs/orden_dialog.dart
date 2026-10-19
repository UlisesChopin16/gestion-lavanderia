import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/dialogs/cliente_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/view_model/orden_dialog_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/widgets/widgets.dart';

/// El alta de una orden de servicio.
///
/// En la aplicación anterior era la segunda pestaña del módulo —una pantalla
/// entera al lado del listado—, y aquí es un diálogo que se abre desde él:
/// dar de alta una orden es lo que se hace *desde* la lista, igual que en los
/// catálogos, y así no hay dos sitios donde pueda estar uno dentro de órdenes.
///
/// Se arma en tres pasos numerados, de izquierda a derecha: a quién es, qué
/// ropa trae y cuánto se cobra. Los dos primeros van en la columna izquierda
/// porque son los que llevan trabajo —buscar, elegir— y el resultado se va
/// viendo en la derecha, que es a la vez el resumen y lo que se firma: la
/// ropa elegida arriba y el cobro abajo.
///
/// No usa `BaseDialog`: ese es el molde de los diálogos que preguntan algo
/// —un aviso, una confirmación, un formulario corto— y se miden por su
/// contenido. Este es una mesa de trabajo, y lo que necesita es sitio: se
/// queda con la ventana hasta un tope, porque amontonar dos listas y un cobro
/// en el ancho de un formulario es lo que hacía lenta la captura.
///
/// Se cierra devolviendo `true` cuando la orden quedó guardada, que es lo que
/// el listado espera para releerse.
class OrdenDialog extends ConsumerWidget {
  const OrdenDialog({super.key});

  /// Lo que el diálogo mide como mucho. Más ancho que esto no ayuda: las dos
  /// columnas se separan tanto que hay que mover la cabeza entre una y otra.
  static const double anchoMaximo = 1120;
  static const double altoMaximo = 760;

  /// Por debajo de este ancho las dos columnas se apilan: en una ventana
  /// angosta, media pantalla por columna no alcanza ni para el buscador.
  static const double _corteDosColumnas = 880;

  /// Lo que separa el contenido de las orillas del diálogo.
  static const double _relleno = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ordenDialogViewModelProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
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
            const _Encabezado(),
            if (estado.mensajeError.isNotEmpty)
              _Aviso(mensaje: estado.mensajeError),
            Expanded(
              child: estado.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _Cuerpo(estado: estado),
            ),
            _Pie(estado: estado),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.post_add_rounded, color: scheme.onPrimary),
          Expanded(
            child: Text(
              'Nueva orden de servicio',
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: Icon(Icons.close_rounded, color: scheme.onPrimary),
            tooltip: 'Cerrar sin guardar',
          ),
        ],
      ),
    );
  }
}

/// Los tres pasos: cliente y prendas a la izquierda, la orden a la derecha.
class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.estado});

  final OrdenDialogState estado;

  /// Lo que miden las dos listas cuando el diálogo se apila en una sola
  /// columna y ya no puede repartirse el alto.
  static const double _altoApilado = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < OrdenDialog._corteDosColumnas) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(OrdenDialog._relleno),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _Eleccion(estado: estado, altoCatalogo: _altoApilado),
                const Divider(height: 1),
                _Resumen(estado: estado, altoRenglones: _altoApilado),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(OrdenDialog._relleno),
                child: _Eleccion(estado: estado),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(OrdenDialog._relleno),
                child: _Resumen(estado: estado),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lo que hay que elegir: el cliente y las prendas.
class _Eleccion extends ConsumerWidget {
  const _Eleccion({required this.estado, this.altoCatalogo});

  final OrdenDialogState estado;

  /// En `null` el catálogo se queda con el alto que sobre; con un valor mide
  /// eso, que es lo que necesita dentro de un desplazable.
  final double? altoCatalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordenDialogViewModelProvider.notifier);

    final catalogo = CatalogoConceptos(
      conceptos: estado.conceptosVisibles,
      categorias: estado.categorias,
      busqueda: estado.busquedaConcepto,
      categoriaId: estado.categoriaId,
      cantidadDe: estado.cantidadDe,
      onBuscar: notifier.buscarConcepto,
      onCategoria: notifier.filtrarCategoria,
      onAgregar: notifier.agregar,
    );

    final alto = altoCatalogo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SelectorCliente(
          busqueda: estado.busquedaCliente,
          encontrados: estado.encontrados,
          cliente: estado.cliente,
          onBuscar: notifier.buscarCliente,
          onElegir: notifier.elegirCliente,
          onQuitar: notifier.quitarCliente,
          onRegistrar: () => _registrarCliente(context, ref),
        ),
        const Divider(height: 1),
        if (alto == null)
          Expanded(child: catalogo)
        else
          SizedBox(height: alto, child: catalogo),
      ],
    );
  }

  /// Da de alta al cliente sin salir de la orden.
  ///
  /// Al volver se repite la búsqueda con lo que estaba escrito: el alta se
  /// acaba de capturar con ese mismo dato, así que el recién registrado queda
  /// elegido y no hay que buscarlo de nuevo.
  Future<void> _registrarCliente(BuildContext context, WidgetRef ref) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => ClienteDialog(busqueda: estado.busquedaCliente),
    );

    if (guardado != true) return;

    await ref
        .read(ordenDialogViewModelProvider.notifier)
        .repetirBusquedaDeCliente();
  }
}

/// Lo que va quedando: la ropa elegida y lo que se cobra por ella.
class _Resumen extends ConsumerWidget {
  const _Resumen({required this.estado, this.altoRenglones});

  /// En `null` la lista de renglones se queda con el alto que sobre.
  final double? altoRenglones;

  final OrdenDialogState estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordenDialogViewModelProvider.notifier);
    final theme = Theme.of(context);

    final renglones = RenglonesOrden(
      items: estado.items.toList(),
      onCantidad: notifier.cambiarCantidad,
      onEntrega: notifier.cambiarEntrega,
      onQuitar: notifier.quitar,
    );

    final alto = altoRenglones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        PasoTitulo(
          numero: '3',
          titulo: 'La orden',
          acompanante: Text(
            estado.items.isEmpty
                ? 'Sin prendas'
                : '${estado.items.length} conceptos',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (alto == null)
          Expanded(child: renglones)
        else
          SizedBox(height: alto, child: renglones),
        CobroOrden(
          total: estado.total,
          abono: estado.abono,
          metodoPago: estado.metodoPago,
          entregaEstimada: estado.entregaEstimada,
          onAbono: notifier.cambiarAbono,
          onMetodoPago: notifier.elegirMetodoPago,
        ),
      ],
    );
  }
}

/// La nota de la orden y los dos botones con los que se sale.
class _Pie extends ConsumerWidget {
  const _Pie({required this.estado});

  final OrdenDialogState estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ordenDialogViewModelProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(OrdenDialog._relleno),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: VRow(
        gutter: 12,
        align: VAlign.center,
        children: [
          VCol(
            cols: 12,
            md: VCol.grow,
            child: FormTextField(
              label: 'Nota de la orden (opcional)',
              hint: 'Una mancha, una prenda delicada, dónde se entrega…',
              icon: Icons.sticky_note_2_outlined,
              value: estado.descripcion,
              onChanged: notifier.cambiarDescripcion,
            ),
          ),
          VCol(
            cols: 12,
            md: VCol.auto,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  // Sin cliente o sin ropa no hay orden que crear: el botón
                  // se ve apagado en lugar de aceptar y fallar después.
                  onPressed: estado.puedeGuardar
                      ? () => _guardar(context, ref)
                      : null,
                  icon: estado.guardando
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  // El total va en el botón: es la última cifra que se mira
                  // antes de cobrar, y así no hay que buscarla en la columna.
                  label: Text(
                    'Crear orden · ${estado.total.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final guardada = await ref
        .read(ordenDialogViewModelProvider.notifier)
        .guardar();

    if (!guardada || !context.mounted) return;

    Navigator.of(context).pop(true);
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
