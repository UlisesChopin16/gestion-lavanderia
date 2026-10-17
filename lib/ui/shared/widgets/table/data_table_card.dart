import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/button_clear_filters.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_action.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_column.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_small_list.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Qué hacer cuando se pide ordenar por [column].
///
/// `ascending` ya viene resuelto: al tocar la columna que ya ordena llega
/// invertido, y al tocar otra llega ascendente.
typedef SortChanged<C> = void Function(C column, bool ascending);

/// El contenido de un listado: buscador, filtros, y la lista como tabla o como
/// tarjetas según el ancho disponible.
///
/// Recibe las filas tal como vienen de la base ([T]) y las columnas que las
/// describen, y arma la tabla. No recibe `DataColumn` ni `DataRow` ya
/// construidos —como hacía la versión anterior, que los desarmaba a la fuerza
/// con `label as Text` para volverlos a armar—, así que una celda ya no puede
/// romper la tabla en tiempo de ejecución.
///
/// La columna de acciones la agrega esta clase cuando hay [actionsBuilder]; la
/// lista de celdas sale sólo de [columns] y por eso siempre coincide con el
/// número de encabezados.
///
/// ```dart
/// DataTableCard<PrecioData, ColumnPreciosName>(
///   rows: precios,
///   sortedBy: filtros.ordenamiento,
///   ascending: filtros.ascendente,
///   onSort: notifier.setOrdenAndSort,
///   addLabel: 'Agregar concepto',
///   onAdd: _onAgregar,
///   onSearchChanged: notifier.setNombre,
///   initialSearch: filtros.nombre,
///   haveFilters: filtros.haveFilters,
///   onClearFilters: notifier.clearFilters,
///   rowKey: (precio) => precio.id,
///   columns: [
///     TableColumnDef.text(
///       title: 'Concepto',
///       value: (precio) => precio.nombreConcepto,
///       sortBy: ColumnPreciosName.nombre,
///       primary: true,
///     ),
///     TableColumnDef.text(
///       title: 'Importe',
///       value: (precio) => precio.importe.toStringAsFixed(2),
///       sortBy: ColumnPreciosName.importe,
///       numeric: true,
///     ),
///   ],
///   actionsBuilder: (precio) => [
///     TableAction(
///       label: 'Editar concepto',
///       icon: Icons.edit,
///       color: Colors.blue,
///       onPressed: () => _onEditar(precio),
///     ),
///   ],
/// )
/// ```
class DataTableCard<T, C> extends StatefulWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.sortedBy,
    this.ascending = true,
    this.onSort,
    this.actionsBuilder,
    this.rowKey,
    this.onRowTap,
    this.leadingBuilder,
    this.smallItemBuilder,
    this.forceSmall,
    this.smallBreakpoint = ConstantsManager.mediumScreen,
    this.filters = const [],
    this.haveFilters = false,
    this.onClearFilters,
    this.onSearchChanged,
    this.initialSearch = '',
    this.searchLabel = 'Buscar',
    this.searchDebounce = const Duration(milliseconds: 300),
    this.addLabel,
    this.onAdd,
    this.isLoading = false,
    this.emptyMessage = 'No hay elementos disponibles',
    this.footer,
  }) : assert(columns.length > 0, 'La tabla necesita al menos una columna');

  final List<TableColumnDef<T, C>> columns;
  final List<T> rows;

  /// Columna por la que la lista viene ordenada, para marcar su encabezado.
  final C? sortedBy;
  final bool ascending;

  /// En `null` ningún encabezado responde al toque.
  final SortChanged<C>? onSort;

  /// Las acciones de cada fila. En `null` no hay columna de acciones: así se
  /// oculta cuando la interfaz está bloqueada, sin quitar celdas después.
  final RowActions<T>? actionsBuilder;

  /// Identidad de la fila. Con ella Flutter reconoce las filas entre dos
  /// consultas y no reconstruye las que no cambiaron.
  final Object Function(T row)? rowKey;
  final ValueChanged<T>? onRowTap;

  /// Icono o avatar al inicio de la tarjeta, en la vista compacta.
  final RowLeadingBuilder<T>? leadingBuilder;

  /// Tarjeta completa de la vista compacta, cuando la de omisión no alcanza.
  final SmallItemBuilder<T>? smallItemBuilder;

  /// Fuerza la vista compacta (`true`) o la tabla (`false`). En `null` se
  /// decide por el ancho que la tabla recibe, y no por el de la pantalla:
  /// dentro de un panel angosto la tabla no cabe aunque la ventana sea ancha.
  final bool? forceSmall;
  final double smallBreakpoint;

  /// Filtros propios de cada listado, sobre la tabla.
  final List<Widget> filters;

  /// Si hay algún filtro aplicado, para mostrar el botón que los limpia.
  final bool haveFilters;
  final VoidCallback? onClearFilters;

  final ValueChanged<String>? onSearchChanged;

  /// Texto con el que arranca el buscador, para los filtros que se guardan
  /// entre sesiones.
  final String initialSearch;
  final String searchLabel;

  /// Cuánto se espera después de la última tecla antes de buscar. Sin esa
  /// espera, escribir "pantalón" lanza ocho consultas a la base.
  final Duration searchDebounce;

  /// Texto del botón de agregar. El botón aparece sólo si hay texto y [onAdd]:
  /// sin callback no habría nada que hacer con él.
  final String? addLabel;
  final VoidCallback? onAdd;

  final bool isLoading;
  final String emptyMessage;

  /// Debajo de la lista: la paginación, un total, un resumen.
  final Widget? footer;

  @override
  State<DataTableCard<T, C>> createState() => _DataTableCardState<T, C>();
}

class _DataTableCardState<T, C> extends State<DataTableCard<T, C>> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialSearch,
  );
  final ScrollController _horizontal = ScrollController();
  Timer? _debounce;

  @override
  void dispose() {
    // Los tres sobreviven al widget si no se cierran aquí: el temporizador
    // dispararía una búsqueda sobre un estado ya desmontado, y los dos
    // controladores quedarían retenidos.
    _debounce?.cancel();
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// Posición del encabezado que ordena la lista.
  ///
  /// Se busca por identidad de columna y no por `enum.index`: el enum y las
  /// columnas visibles no siempre coinciden —precios esconde la columna de
  /// categoría cuando ya se filtró por una— y `DataTable` exige un índice
  /// dentro del rango. Si la columna ordenada no está visible no se marca
  /// ninguna, en lugar de pasar un índice inválido.
  int? get _sortColumnIndex {
    final sortedBy = widget.sortedBy;
    if (sortedBy == null) return null;

    final index = widget.columns.indexWhere(
      (column) => column.sortBy == sortedBy,
    );

    return index < 0 ? null : index;
  }

  bool get _hasActions => widget.actionsBuilder != null;

  bool get _showAddButton => widget.addLabel != null && widget.onAdd != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      // El LayoutBuilder va dentro del Padding para que el ancho que mide sea
      // el que la tabla puede ocupar de verdad.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final isSmall = widget.forceSmall ?? width < widget.smallBreakpoint;

          return Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SearchAndAdd(
                controller: _search,
                label: widget.searchLabel,
                onSearchChanged: widget.onSearchChanged == null
                    ? null
                    : _onSearchChanged,
                addLabel: _showAddButton ? widget.addLabel : null,
                onAdd: widget.onAdd,
              ),
              const Divider(height: 0),
              if (widget.filters.isNotEmpty || widget.haveFilters)
                _Filters(
                  filters: widget.filters,
                  haveFilters: widget.haveFilters,
                  onClearFilters: _clearFilters,
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _body(context, isSmall: isSmall, maxWidth: width),
              ),
              if (widget.footer != null) widget.footer!,
            ],
          );
        },
      ),
    );
  }

  /// La lista, el aviso de vacío o el indicador de carga: nunca dos a la vez,
  /// que es lo que pasaba antes, cuando una lista vacía mostraba la tabla con
  /// sólo encabezados y el mensaje debajo.
  Widget _body(
    BuildContext context, {
    required bool isSmall,
    required double maxWidth,
  }) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    if (isSmall) {
      return TableSmallList<T, C>(
        columns: widget.columns,
        rows: widget.rows,
        actionsBuilder: widget.actionsBuilder,
        leadingBuilder: widget.leadingBuilder,
        itemBuilder: widget.smallItemBuilder,
        onRowTap: widget.onRowTap,
        rowKey: widget.rowKey,
      );
    }

    return _scrollableTable(context, maxWidth);
  }

  Widget _scrollableTable(BuildContext context, double maxWidth) {
    final table = DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: widget.ascending,
      showCheckboxColumn: false,
      columns: _buildColumns(),
      rows: _buildRows(context),
    );

    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      child: ScrollConfiguration(
        // Arrastrar con el ratón: en escritorio no hay gesto táctil y una
        // tabla ancha quedaría sólo a merced de la rueda. Antes esto se hacía
        // con un GestureDetector que llamaba a `jumpTo` sin acotar el
        // resultado, de modo que el arrastre podía salirse del rango.
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          // La tabla ocupa todo el ancho disponible y sólo se desborda —y se
          // desplaza— cuando sus columnas no caben.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: maxWidth),
            child: table,
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    final onSort = widget.onSort;

    return [
      for (final column in widget.columns)
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          numeric: column.numeric,
          tooltip: column.tooltip,
          columnWidth: column.width,
          onSort: !column.isSortable || onSort == null
              ? null
              : (_, ascending) => onSort(column.sortBy as C, ascending),
          label: Flexible(
            child: Text(
              column.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      if (_hasActions)
        const DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text('Acciones'),
        ),
    ];
  }

  List<DataRow> _buildRows(BuildContext context) {
    final stripes = ColorRowTheme.of(context);
    final actionsBuilder = widget.actionsBuilder;
    final onRowTap = widget.onRowTap;
    final rowKey = widget.rowKey;

    return [
      for (final (index, row) in widget.rows.indexed)
        DataRow(
          key: rowKey == null ? null : ValueKey(rowKey(row)),
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return stripes.hoverColor;
            return stripes.colorForRow(index);
          }),
          onSelectChanged: onRowTap == null ? null : (_) => onRowTap(row),
          mouseCursor: WidgetStatePropertyAll(
            onRowTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
          ),
          cells: [
            for (final column in widget.columns)
              DataCell(
                Align(
                  alignment: column.numeric
                      ? Alignment.centerRight
                      : Alignment.center,
                  child: column.buildCell(context, row),
                ),
              ),
            if (actionsBuilder != null)
              DataCell(TableActionsCell(actions: actionsBuilder(row))),
          ],
        ),
    ];
  }

  void _onSearchChanged(String value) {
    final onSearchChanged = widget.onSearchChanged;
    if (onSearchChanged == null) return;

    _debounce?.cancel();

    if (widget.searchDebounce <= Duration.zero) {
      onSearchChanged(value);
      return;
    }

    _debounce = Timer(widget.searchDebounce, () => onSearchChanged(value));
  }

  /// Limpia el buscador y avisa al listado para que reponga sus filtros.
  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    widget.onClearFilters?.call();
  }
}

class _SearchAndAdd extends StatelessWidget {
  const _SearchAndAdd({
    required this.controller,
    required this.label,
    this.onSearchChanged,
    this.addLabel,
    this.onAdd,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSearchChanged;
  final String? addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final addLabel = this.addLabel;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      runAlignment: WrapAlignment.end,
      spacing: 15,
      runSpacing: 10,
      children: [
        if (onSearchChanged != null)
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              constraints: const BoxConstraints(maxWidth: 300),
              labelText: label,
              suffixIcon: const Icon(IconsManager.search),
            ),
          ),
        if (addLabel != null)
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(IconsManager.add),
            label: Text(addLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            ),
          ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filters,
    required this.haveFilters,
    required this.onClearFilters,
  });

  final List<Widget> filters;
  final bool haveFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      runAlignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (haveFilters) ButtonClearFilters(onPressed: onClearFilters),
        ...filters,
      ],
    );
  }
}
