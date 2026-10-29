import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogo_pendiente.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/orden_detalle_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/orden_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/orden_historial_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/view_model/ordenes_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// El listado de órdenes de servicio: el módulo entero.
///
/// En la aplicación anterior el módulo eran dos pestañas —la lista y el alta—,
/// y la segunda era una pantalla completa al lado de la primera. Aquí el
/// módulo es la lista, y dar de alta una orden es un diálogo que se abre desde
/// ella: es lo mismo que hacen los catálogos, y así no hay dos sitios donde
/// pueda estar uno dentro de órdenes.
///
/// Es la lista más ancha de la aplicación —una orden se describe con su
/// cliente, su estatus, lo que cuesta, lo que debe, cómo se pagó y tres
/// fechas—, así que casi siempre se recorre a lo ancho. Por eso ordenar vive
/// en el desplegable de los filtros y no en los encabezados: la columna por la
/// que se quiere ordenar puede estar fuera de la parte visible.
class OrdenesView extends ConsumerWidget {
  const OrdenesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ordenesViewModelProvider);
    final notifier = ref.read(ordenesViewModelProvider.notifier);
    final filtros = estado.filtros;

    return ListadoCard(
      mensajeError: estado.mensajeError,
      child: DataTableCard<OrdenListadoData>(
        rows: estado.pagina,
        isLoading: estado.cargando,
        emptyMessage: filtros.haveFilters
            ? 'Ninguna orden coincide con los filtros.'
            : 'Todavía no hay órdenes registradas.',
        rowKey: (orden) => orden.id,

        // El encabezado: el nombre del módulo a la izquierda y el alta
        // enfrente. Donde los catálogos ponen sus pestañas, órdenes pone su
        // título: no hay otra lista entre la que elegir.
        seccionEncabezado: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const TitleContainer(
              title: 'Órdenes de servicio',
              icon: IconsManager.selectedOrdenServicioIcon,
            ),
            ButtonAdd(
              label: 'Nueva orden',
              onPressed: () => _agregar(context, ref),
            ),
          ],
        ),

        // Seis filtros: el buscador, los tres por los que se acota —estatus,
        // método de pago y fechas de creación—, el orden y el botón que lo
        // limpia todo. Cada uno se queda con un tercio del renglón en una
        // ventana ancha, con la mitad en una mediana y con el renglón entero
        // en una angosta.
        seccionFiltros: VRow(
          gutter: 12,
          align: VAlign.center,
          children: [
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: SearchFilter(
                label: 'Buscar por folio o cliente',
                value: filtros.busqueda,
                onChanged: notifier.buscar,
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: FiltroEstatusOrden(
                estatus: filtros.estatus,
                onChanged: notifier.filtrarEstatus,
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: FiltroMetodoPago(
                metodoPago: filtros.metodoPago,
                onChanged: notifier.filtrarMetodoPago,
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: DateRangePicker(
                labelText: 'Fechas de creación',
                selectedDates: estado.rangoCreacion,
                changeDate: notifier.filtrarFechas,
                onDelete: notifier.quitarFechas,
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: SortDropdown<ColumnsOrdenesNames>(
                columns: ColumnsOrdenesNames.values,
                selected: filtros.ordenamiento,
                ascending: filtros.ascendente,
                onColumnChanged: (columna) =>
                    notifier.ordenar(columna, filtros.ascendente),
                onAscendingChanged: (ascendente) =>
                    notifier.ordenar(filtros.ordenamiento, ascendente),
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: ButtonClearFilters(onPressed: notifier.limpiarFiltros),
            ),
          ],
        ),

        pagination: TablePagination(
          paginacion: estado.paginacion,
          onPaginaChanged: notifier.irAPagina,
          onPorPaginaChanged: notifier.cambiarFilasPorPagina,
        ),

        columns: [
          TableColumnDef.text(
            title: 'Folio',
            value: (orden) => orden.folio,
            size: TableColumnSize.compacta,
          ),
          TableColumnDef.text(
            title: 'Cliente',
            value: (orden) => orden.cliente,
            size: TableColumnSize.amplia,
          ),
          TableColumnDef.widget(
            title: 'Estatus',
            content: (context, orden) =>
                EstatusOrdenChip(estatus: orden.estatus),
          ),
          TableColumnDef.text(
            title: 'Total',
            value: (orden) => orden.total.toStringAsFixed(2),
            numeric: true,
            size: TableColumnSize.compacta,
          ),
          TableColumnDef.text(
            title: 'Restante',
            value: (orden) => orden.restante.toStringAsFixed(2),
            numeric: true,
            size: TableColumnSize.compacta,
          ),
          TableColumnDef.text(
            title: 'Método de Pago',
            value: (orden) => orden.metodoPago.value,
          ),
          TableColumnDef.text(
            title: 'Fecha de Creación',
            value: (orden) => orden.fechaCreacion.formatFullDate,
          ),
          TableColumnDef.text(
            title: 'Última Interacción',
            value: (orden) => orden.ultimaInteraccion.formatFullDate,
          ),
          TableColumnDef.text(
            title: 'Fecha de Cierre',
            value: (orden) => orden.fechaCierre.formatFullDate,
          ),
          // Las acciones son una columna más, la última: de ancho fijo porque
          // lo que llevan dentro no cambia de tamaño con los datos.
          TableColumnDef.widget(
            title: 'Acciones',
            size: const TableColumnSize.fija(TableActionsCell.ancho),
            content: (context, orden) => TableActionsCell(
              // Siempre en menú: una orden cerrada lleva una acción menos, y
              // con dos la celda las pondría en línea. La columna quedaría
              // con menús en unas filas y botones sueltos en otras.
              compact: true,
              actions: [
                TableAction(
                  label: 'Ver historial de la orden',
                  icon: Icons.history_rounded,
                  color: Colors.blue,
                  onPressed: () => _verHistorial(context, orden),
                ),
                // Una orden cerrada ya está pagada y entregada: en el detalle
                // no queda nada que cobrar ni que entregar, y lo que pasó con
                // ella se consulta en el historial.
                if (orden.estatus != EstatusOrdenType.cerrada)
                  TableAction(
                    label: 'Ver la orden',
                    icon: Icons.assignment_turned_in_rounded,
                    color: orden.estatus.color,
                    onPressed: () => _verOrden(context, ref, orden),
                  ),
                TableAction(
                  label: 'Ver ticket de la orden',
                  icon: IconsManager.selectedOrdenServicioIcon,
                  color: Colors.amber,
                  onPressed: () => _pendiente(
                    context,
                    titulo: 'Ticket de la orden',
                    orden: orden,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abre el alta, relee el listado si se guardó algo y confirma con qué
  /// folio quedó la orden.
  ///
  /// La relectura se pide aquí y no dentro del diálogo porque el listado es de
  /// esta pantalla: el diálogo sólo devuelve el folio de lo que guardó.
  ///
  /// El aviso va después de releer para que la orden ya esté en la tabla
  /// cuando se cierre: se confirma y se ve, en ese orden. Y lleva el folio
  /// porque es el número con el que se busca la orden después —el del ticket
  /// que se lleva el cliente—, no un dato de la base que dé igual.
  Future<void> _agregar(BuildContext context, WidgetRef ref) async {
    final folio = await showDialog<String>(
      context: context,
      builder: (context) => const OrdenDialog(),
    );

    if (folio == null) return;

    await ref.read(ordenesViewModelProvider.notifier).cargar();

    if (!context.mounted) return;

    await context.showSuccessDialog('La orden $folio se creó correctamente.');
  }

  /// Abre el detalle de la orden y, si se cobró o se entregó algo, relee el
  /// listado y dice qué se registró.
  ///
  /// Mismo orden que el alta: primero se relee, para que la fila ya traiga su
  /// saldo y su estatus nuevos cuando se cierre el aviso.
  Future<void> _verOrden(
    BuildContext context,
    WidgetRef ref,
    OrdenListadoData orden,
  ) async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (context) => OrdenDetalleDialog(ordenId: orden.id),
    );

    if (mensaje == null) return;

    await ref.read(ordenesViewModelProvider.notifier).cargar();

    if (!context.mounted) return;

    await context.showSuccessDialog(mensaje);
  }

  /// Abre el historial de la orden. Sólo se mira, así que no hay nada que
  /// releer al cerrarlo.
  Future<void> _verHistorial(BuildContext context, OrdenListadoData orden) {
    return showDialog<void>(
      context: context,
      builder: (context) => OrdenHistorialDialog(ordenId: orden.id),
    );
  }

  /// Lo que todavía no se ha portado de este módulo: el ticket de la orden.
  /// Sustituirá esta llamada por su diálogo.
  Future<void> _pendiente(
    BuildContext context, {
    required String titulo,
    required OrdenListadoData orden,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => DialogoPendiente(
        titulo: titulo,
        detalle: 'Orden ${orden.folio} · ${orden.cliente}',
      ),
    );
  }
}
