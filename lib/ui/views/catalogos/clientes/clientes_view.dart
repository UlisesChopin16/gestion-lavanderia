import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/dialogs/cliente_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/view_model/clientes_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// El catálogo de clientes.
///
/// Un cliente no se da de baja: queda referido por las órdenes que ya pasaron
/// por el mostrador, así que la única acción sobre el renglón es editarlo.
class ClientesView extends ConsumerWidget {
  const ClientesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(clientesViewModelProvider);
    final notifier = ref.read(clientesViewModelProvider.notifier);
    final filtros = estado.filtros;

    return ListadoCatalogo(
      mensajeError: estado.mensajeError,
      child: DataTableCard<ClienteEntry, ColumnClientesName>(
        rows: estado.pagina,
        isLoading: estado.cargando,
        emptyMessage: filtros.haveFilters
            ? 'Ningún cliente coincide con los filtros.'
            : 'Todavía no hay clientes registrados.',
        rowKey: (cliente) => cliente.id,

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
              label: 'Agregar cliente',
              onPressed: () => _agregar(context),
            ),
          ],
        ),

        sortedBy: filtros.ordenamiento,
        ascending: filtros.ascendente,
        onSort: notifier.ordenar,
        // Clientes sólo se acota por el nombre y por el orden, así que el
        // buscador se queda con más renglón que en los demás listados.
        seccionFiltros: VRow(
          gutter: 12,
          align: VAlign.center,
          children: [
            VCol(
              cols: 12,
              md: 4,
              child: SearchFilter(
                label: 'Buscar cliente',
                value: filtros.nombre,
                onChanged: notifier.buscar,
              ),
            ),
            VCol(
              cols: 12,
              sm: 6,
              md: 4,
              child: SortDropdown<ColumnClientesName>(
                columns: ColumnClientesName.values,
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
            value: (cliente) => '${cliente.id}',
            sortBy: ColumnClientesName.id,
            numeric: true,
            showOnSmall: false,
          ),
          TableColumnDef.text(
            title: 'Nombre(s)',
            value: (cliente) => cliente.nombres,
            sortBy: ColumnClientesName.nombre,
            primary: true,
          ),
          TableColumnDef.text(
            title: 'Apellido(s)',
            value: (cliente) => cliente.apellidos,
            sortBy: ColumnClientesName.apellido,
          ),
          TableColumnDef.text(
            title: 'Teléfono',
            value: (cliente) => cliente.telefono,
            sortBy: ColumnClientesName.telefono,
          ),
          // El correo es opcional: cuando no lo hay se marca como ausente en
          // lugar de dejar la celda en blanco, que se lee como un error.
          TableColumnDef.text(
            title: 'Correo',
            value: (cliente) => cliente.correo.isEmpty
                ? ConstantsManager.emptyValue
                : cliente.correo,
            sortBy: ColumnClientesName.correo,
          ),
          TableColumnDef.text(
            title: 'Fecha de Creación',
            value: (cliente) => cliente.fechaCreacion.formatFullDate,
            sortBy: ColumnClientesName.fechaCreacion,
            showOnSmall: false,
          ),
        ],

        actionsBuilder: (cliente) => [
          TableAction(
            label: 'Editar cliente',
            icon: Icons.edit_rounded,
            color: Colors.blue,
            onPressed: () => _editar(context, cliente),
          ),
        ],
      ),
    );
  }

  Future<void> _agregar(BuildContext context) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => const ClienteDialog(),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('El cliente se registró correctamente.');
  }

  Future<void> _editar(BuildContext context, ClienteEntry cliente) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => ClienteDialog(cliente: cliente),
    );

    if (guardado != true || !context.mounted) return;

    await context.showSuccessDialog('Los datos del cliente se actualizaron.');
  }
}
