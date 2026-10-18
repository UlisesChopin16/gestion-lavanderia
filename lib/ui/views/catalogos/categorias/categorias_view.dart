import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/dialogs/categoria_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/view_model/categorias_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/view_model/catalogos_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/widgets/widgets.dart';

/// El catálogo de categorías de ropa.
///
/// Una categoría agrupa conceptos y les presta sus días de entrega, así que
/// darla de baja arrastra a los suyos y cambiarle los días se los cambia a
/// todos. Las dos cosas se advierten antes de hacerlas.
class CategoriasView extends ConsumerWidget {
  const CategoriasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El encabezado de la tarjeta se nombra como la pestaña: dos
    // etiquetas distintas para lo mismo harían dudar de si son lo mismo.
    const pestana = CatalogosTabsType.categorias;
    final estado = ref.watch(categoriasViewModelProvider);
    final notifier = ref.read(categoriasViewModelProvider.notifier);
    final filtros = estado.filtros;

    return ListadoCatalogo(
      mensajeError: estado.mensajeError,
      child: DataTableCard<CategoriaServicioEntry, ColumnsCategoriaType>(
        rows: estado.pagina,
        isLoading: estado.cargando,
        emptyMessage: filtros.haveFilters
            ? 'Ninguna categoría coincide con los filtros.'
            : 'Todavía no hay categorías de ropa.',
        rowKey: (categoria) => categoria.id,

        searchLabel: 'Buscar categoría',
        initialSearch: filtros.nombre,
        onSearchChanged: notifier.buscar,
        onClearFilters: notifier.limpiarFiltros,
        title: pestana.title,
        titleIcon: pestana.icon,
        addLabel: 'Agregar categoría',
        onAdd: () => _agregar(context),

        sortedBy: filtros.ordenamiento,
        ascending: filtros.ascendente,
        onSort: notifier.ordenar,
        filters: [
          EstatusFilter(
            estatus: filtros.estatus,
            onChanged: notifier.filtrarEstatus,
          ),
          SortDropdown<ColumnsCategoriaType>(
            columns: ColumnsCategoriaType.values,
            selected: filtros.ordenamiento,
            ascending: filtros.ascendente,
            onColumnChanged: (columna) =>
                notifier.ordenar(columna, filtros.ascendente),
            onAscendingChanged: (ascendente) =>
                notifier.ordenar(filtros.ordenamiento, ascendente),
          ),
        ],

        pagination: TablePagination(
          paginacion: estado.paginacion,
          onPaginaChanged: notifier.irAPagina,
          onPorPaginaChanged: notifier.cambiarFilasPorPagina,
        ),

        columns: [
          TableColumnDef.text(
            title: 'ID',
            value: (categoria) => '${categoria.id}',
            sortBy: ColumnsCategoriaType.id,
            numeric: true,
            showOnSmall: false,
          ),
          TableColumnDef.text(
            title: 'Nombre',
            value: (categoria) => categoria.nombre,
            sortBy: ColumnsCategoriaType.nombre,
            primary: true,
          ),
          TableColumnDef.widget(
            title: 'Estatus',
            content: (context, categoria) =>
                EstatusChip(estatus: categoria.estatus),
            sortBy: ColumnsCategoriaType.estatus,
          ),
          TableColumnDef.text(
            title: 'Días de Entrega',
            value: (categoria) => '${categoria.diasEntrega}',
            sortBy: ColumnsCategoriaType.diasEntrega,
            numeric: true,
          ),
          TableColumnDef.text(
            title: 'Fecha de Creación',
            value: (categoria) => categoria.fechaCreacion.formatFullDate,
            sortBy: ColumnsCategoriaType.fechaCreacion,
            showOnSmall: false,
          ),
          TableColumnDef.text(
            title: 'Fecha de Eliminación',
            value: (categoria) => categoria.fechaEliminacion.formatFullDate,
            sortBy: ColumnsCategoriaType.fechaEliminacion,
            showOnSmall: false,
          ),
        ],

        // Las acciones que no aplican no se muestran deshabilitadas, se
        // omiten: editar una categoría dada de baja no es algo que se pueda
        // "habilitar", simplemente no se hace sin reactivarla antes.
        actionsBuilder: (categoria) => [
          TableAction(
            label: 'Ver sus conceptos',
            icon: Icons.visibility_rounded,
            color: Colors.blue,
            onPressed: () => _verConceptos(ref, categoria),
          ),
          if (categoria.estatus == EstatusType.activo) ...[
            TableAction(
              label: 'Editar categoría',
              icon: Icons.edit_rounded,
              color: Colors.amber,
              onPressed: () => _editar(context, categoria),
            ),
            TableAction(
              label: 'Desactivar categoría',
              icon: Icons.delete_rounded,
              color: Colors.red,
              onPressed: () => _desactivar(context, ref, categoria),
            ),
          ] else
            TableAction(
              label: 'Activar categoría',
              icon: Icons.restore_rounded,
              color: Colors.green,
              onPressed: () => _activar(context, ref, categoria),
            ),
        ],
      ),
    );
  }

  /// Abre los precios filtrados por esta categoría.
  ///
  /// Antes esto era un diálogo con la pantalla de precios dentro; ahora lleva
  /// a la pestaña de al lado, que es la misma lista con todas sus acciones y
  /// no una copia encima.
  Future<void> _verConceptos(
    WidgetRef ref,
    CategoriaServicioEntry categoria,
  ) async {
    await ref
        .read(preciosViewModelProvider.notifier)
        .filtrarPorCategoria(
          categoria.id,
          // Los conceptos de una categoría dada de baja están inactivos, así
          // que con el filtro de omisión la lista de destino saldría vacía.
          incluirInactivos: categoria.estatus != EstatusType.activo,
        );

    ref.read(catalogosViewModelProvider.notifier).abrir(
      CatalogosTabsType.precios,
    );
  }

  Future<void> _agregar(BuildContext context) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => const CategoriaDialog(),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('La categoría se creó correctamente.');
  }

  Future<void> _editar(
    BuildContext context,
    CategoriaServicioEntry categoria,
  ) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => CategoriaDialog(categoria: categoria),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('La categoría se actualizó correctamente.');
  }

  Future<void> _desactivar(
    BuildContext context,
    WidgetRef ref,
    CategoriaServicioEntry categoria,
  ) async {
    final confirmado = await context.showWarningDialog(
      message:
          '¿Desactivar la categoría "${categoria.nombre}"?\n'
          'Dejará de estar disponible y se desactivarán también todos sus '
          'conceptos de ropa.',
    );

    if (!confirmado) return;

    await ref.read(categoriasViewModelProvider.notifier).desactivar(
      categoria.id,
    );
  }

  Future<void> _activar(
    BuildContext context,
    WidgetRef ref,
    CategoriaServicioEntry categoria,
  ) async {
    final confirmado = await context.showWarningDialog(
      message:
          '¿Activar la categoría "${categoria.nombre}"?\n'
          'Volverán a quedar disponibles los conceptos que se dieron de baja '
          'con ella.',
    );

    if (!confirmado) return;

    await ref.read(categoriasViewModelProvider.notifier).activar(categoria.id);
  }
}
