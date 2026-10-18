import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/dialogs/precio_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/widgets/widgets.dart';

/// El catálogo de conceptos de ropa con su precio.
///
/// Es la lista más ancha del módulo —un concepto se describe con su categoría,
/// su tamaño, su unidad y sus días de entrega—, así que las columnas de
/// auditoría se esconden en la vista compacta y la tabla se desplaza a lo
/// ancho cuando no caben.
class PreciosView extends ConsumerWidget {
  const PreciosView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(preciosViewModelProvider);
    final notifier = ref.read(preciosViewModelProvider.notifier);
    final filtros = estado.filtros;

    return ListadoCatalogo(
      mensajeError: estado.mensajeError,
      child: DataTableCard<PrecioData, ColumnPreciosName>(
        rows: estado.pagina,
        isLoading: estado.cargando,
        emptyMessage: filtros.haveFilters
            ? 'Ningún concepto coincide con los filtros.'
            : 'Todavía no hay conceptos de ropa.',
        rowKey: (precio) => precio.id,

        // El encabezado: las pestañas del módulo a la izquierda —la marcada
        // dice en qué catálogo está uno— y el alta enfrente. En una ventana
        // angosta el botón baja al renglón siguiente en lugar de desbordarse.
        seccionEncabezado: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const PestanasCatalogo(),
            ButtonAdd(
              label: 'Agregar concepto',
              onPressed: () => _agregar(context, estado.puedeAgregar),
            ),
          ],
        ),

        sortedBy: filtros.ordenamiento,
        ascending: filtros.ascendente,
        onSort: notifier.ordenar,
        // Es el listado con más filtros —estatus, categoría, tamaño y orden—,
        // así que el buscador se queda con un tercio del renglón como mucho y
        // los cuatro desplegables se reparten lo que sobra. Cuando ya no caben
        // con su ancho mínimo, el renglón se parte en dos.
        seccionFiltros: VRow(
          gutter: 12,
          align: VAlign.center,
          children: [
            VCol(
              cols: 12,
              md: 4,
              sm: 6,
              child: SearchFilter(
                label: 'Buscar concepto',
                value: filtros.nombre,
                onChanged: notifier.buscar,
              ),
            ),
            VCol(
              cols: 12,
              md: 4,
              sm: 6,
              child: EstatusFilter(
                estatus: filtros.estatus,
                onChanged: notifier.filtrarEstatus,
              ),
            ),
            VCol(
              cols: 12,
              md: 4,
              sm: 6,
              child: FiltroCategoria(
                categorias: estado.categorias,
                seleccionada: filtros.categoriaId,
                onChanged: notifier.filtrarPorCategoria,
                onQuitar: notifier.quitarCategoria,
              ),
            ),
            VCol(
              cols: 12,
              md: 4,
              sm: 6,
              child: SelectorTamano(
                tamano: filtros.clotheSize,
                permiteQuitar: true,
                onQuitar: () => notifier.filtrarTamano(null),
                onChanged: notifier.filtrarTamano,
              ),
            ),
            VCol(
              cols: 12,
              md: 4,
              sm: 6,
              child: SortDropdown<ColumnPreciosName>(
                columns: ColumnPreciosName.values,
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
              md: 4,
              sm: 6,
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
            title: 'ID',
            value: (precio) => '${precio.id}',
            sortBy: ColumnPreciosName.id,
            numeric: true,
            showOnSmall: false,
          ),
          TableColumnDef.text(
            title: 'Concepto',
            value: (precio) => precio.nombreConcepto,
            sortBy: ColumnPreciosName.nombre,
            primary: true,
          ),
          TableColumnDef.text(
            title: 'Categoría',
            value: (precio) => precio.categoria,
            sortBy: ColumnPreciosName.categoria,
          ),
          TableColumnDef.text(
            title: 'Tamaño',
            value: (precio) => precio.clotheSize.description,
            sortBy: ColumnPreciosName.sizeRopa,
          ),
          TableColumnDef.text(
            title: 'Unidad',
            value: (precio) => precio.tipoUnidad.value,
            sortBy: ColumnPreciosName.tipoUnidad,
          ),
          TableColumnDef.text(
            title: 'Días de Entrega',
            value: (precio) => '${precio.diasEntrega}',
            sortBy: ColumnPreciosName.diasEntrega,
            numeric: true,
          ),
          TableColumnDef.text(
            title: '\$ Importe',
            value: (precio) => precio.importe.toStringAsFixed(2),
            sortBy: ColumnPreciosName.importe,
            numeric: true,
          ),
          TableColumnDef.widget(
            title: 'Estatus',
            content: (context, precio) => EstatusChip(estatus: precio.estatus),
            sortBy: ColumnPreciosName.estatus,
          ),
          TableColumnDef.text(
            title: 'Fecha de Creación',
            value: (precio) => precio.fechaCreacion.formatFullDate,
            sortBy: ColumnPreciosName.fechaCreacion,
            showOnSmall: false,
          ),
          TableColumnDef.text(
            title: 'Fecha de Eliminación',
            value: (precio) => precio.fechaEliminacion.formatFullDate,
            sortBy: ColumnPreciosName.fechaEliminacion,
            showOnSmall: false,
          ),
        ],

        actionsBuilder: (precio) => [
          if (precio.estaActivo) ...[
            TableAction(
              label: 'Editar concepto',
              icon: Icons.edit_rounded,
              color: Colors.blue,
              onPressed: () => _editar(context, precio),
            ),
            TableAction(
              label: 'Desactivar concepto',
              icon: Icons.delete_rounded,
              color: Colors.red,
              onPressed: () => _desactivar(context, ref, precio),
            ),
          ] else
            TableAction(
              label: 'Activar concepto',
              icon: Icons.restore_rounded,
              color: Colors.green,
              onPressed: () => _activar(context, ref, precio),
            ),
        ],
      ),
    );
  }

  /// Un concepto vive dentro de una categoría, así que sin categorías activas
  /// no hay alta posible: se dice dónde empezar en lugar de abrir un
  /// formulario que no se va a poder guardar.
  Future<void> _agregar(BuildContext context, bool puedeAgregar) async {
    if (!puedeAgregar) {
      await context.showErrorDialog(
        'No hay categorías de ropa activas. Crea una categoría antes de '
        'agregar conceptos.',
      );
      return;
    }

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => const PrecioDialog(),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('El concepto se creó correctamente.');
  }

  Future<void> _editar(BuildContext context, PrecioData precio) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => PrecioDialog(precio: precio),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('El concepto se actualizó correctamente.');
  }

  Future<void> _desactivar(
    BuildContext context,
    WidgetRef ref,
    PrecioData precio,
  ) async {
    final confirmado = await context.showWarningDialog(
      message:
          '¿Desactivar "${precio.descripcion}" de la categoría '
          '"${precio.categoria}"?\n'
          'Dejará de poder cobrarse en una orden nueva.',
    );

    if (!confirmado) return;

    await ref.read(preciosViewModelProvider.notifier).desactivar(precio.id);
  }

  Future<void> _activar(
    BuildContext context,
    WidgetRef ref,
    PrecioData precio,
  ) async {
    final confirmado = await context.showWarningDialog(
      message:
          '¿Activar "${precio.descripcion}" de la categoría '
          '"${precio.categoria}"?',
    );

    if (!confirmado) return;

    await ref.read(preciosViewModelProvider.notifier).activar(precio.id);
  }
}
