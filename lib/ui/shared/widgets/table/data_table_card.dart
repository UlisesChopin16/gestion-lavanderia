import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
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

/// El contenido de un listado: su encabezado, los filtros, la paginación y la
/// lista como tabla o como tarjetas según el ancho disponible.
///
/// De arriba abajo:
///
/// 1. el encabezado —el nombre del listado y el botón de agregar—, cerrado por
///    una línea;
/// 2. los filtros —el buscador entre ellos—, tal como los arme la pantalla;
/// 3. la paginación;
/// 4. la lista.
///
/// Los tres últimos van separados por el mismo aire.
///
/// La paginación va *antes* de la lista y no al pie: en una tabla de diez
/// renglones el pie queda a media pantalla, y con la lista larga había que
/// recorrerla entera para cambiar de página. Arriba está siempre en el mismo
/// sitio, junto a los filtros con los que se usa.
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
///   onSort: notifier.ordenar,
///   title: 'Precios de ropa',
///   titleIcon: IconsManager.selectedPreciosIcon,
///   addLabel: 'Agregar concepto',
///   onAdd: _onAgregar,
///   seccionFiltros: VRow(
///     gutter: 12,
///     align: VAlign.center,
///     children: [
///       VCol(
///         cols: 12,
///         md: 5,
///         lg: 4,
///         child: SearchFilter(
///           label: 'Buscar concepto',
///           value: filtros.nombre,
///           onChanged: notifier.buscar,
///         ),
///       ),
///       VCol(
///         cols: 12,
///         sm: 6,
///         md: VCol.grow,
///         child: EstatusFilter(
///           estatus: filtros.estatus,
///           onChanged: notifier.filtrar,
///         ),
///       ),
///       VCol(
///         cols: 12,
///         sm: VCol.auto,
///         child: ButtonClearFilters(onPressed: notifier.limpiarFiltros),
///       ),
///     ],
///   ),
///   pagination: TablePagination(...),
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
    this.seccionFiltros,
    this.title,
    this.titleIcon,
    this.addLabel,
    this.onAdd,
    this.isLoading = false,
    this.emptyMessage = 'No hay elementos disponibles',
    this.pagination,
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

  /// Con qué se acota el listado: los filtros, el buscador y el botón de
  /// limpiarlos, ya armados por la pantalla.
  ///
  /// La tarjeta no sabe cuáles son, cómo se ven ni cómo se reparten el ancho:
  /// los pone tal cual entre el encabezado y la paginación. Quien los arma es
  /// la pantalla, que es la que sabe por qué se filtra ese listado y cuánto
  /// sitio merece cada control, así que dos listados con filtros distintos no
  /// tienen que caber en el mismo molde.
  ///
  /// Lo habitual es un `VRow` con una columna por control. En `null` no se
  /// dibuja nada y la lista queda justo debajo del encabezado.
  final Widget? seccionFiltros;

  /// El nombre del listado, en el encabezado de la tarjeta. En `null` el
  /// encabezado sólo lleva el botón de agregar.
  final String? title;
  final IconData? titleIcon;

  /// Texto del botón de agregar. El botón aparece sólo si hay texto y [onAdd]:
  /// sin callback no habría nada que hacer con él.
  final String? addLabel;
  final VoidCallback? onAdd;

  final bool isLoading;
  final String emptyMessage;

  /// Entre los filtros y la lista: la paginación, un total, un resumen.
  final Widget? pagination;

  /// Las llaves de los tres bloques.
  ///
  /// Están para que una prueba pueda medir el aire que los separa sin
  /// depender de cómo esté armado el interior del componente, que es lo que
  /// hace que una prueba de disposición se rompa al refactorizar.
  static const llaveEncabezado = Key('data-table-card-encabezado');
  static const llaveFiltros = Key('data-table-card-filtros');
  static const llavePaginacion = Key('data-table-card-paginacion');
  static const llaveLista = Key('data-table-card-lista');

  @override
  State<DataTableCard<T, C>> createState() => _DataTableCardState<T, C>();
}

class _DataTableCardState<T, C> extends State<DataTableCard<T, C>> {
  final ScrollController _horizontal = ScrollController();

  /// El aire entre los tres bloques: 1.5 rem.
  ///
  /// Es el mismo entre los controles y la paginación que entre la paginación y
  /// la lista, para que los tres se lean como tres cosas al mismo nivel y no
  /// como una pegada a otra.
  static const double _espacio = 24;

  /// Lo que separa el contenido del borde de la tarjeta.
  static const double _relleno = 20;

  /// El redondeo de los recuadros: el del encabezado y el de la tabla.
  static const double _radio = 16;

  @override
  void dispose() {
    // El controlador sobrevive al widget si no se cierra aquí.
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
      padding: const EdgeInsets.all(_relleno),
      // El LayoutBuilder va dentro del Padding para que el ancho que mide sea
      // el que la tabla puede ocupar de verdad.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final isSmall = widget.forceSmall ?? width < widget.smallBreakpoint;

          return Column(
            spacing: _espacio,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null || _showAddButton)
                _Encabezado(
                  key: DataTableCard.llaveEncabezado,
                  titulo: widget.title,
                  icono: widget.titleIcon,
                  radio: _radio,
                  addLabel: _showAddButton ? widget.addLabel : null,
                  onAdd: widget.onAdd,
                ),
              if (widget.seccionFiltros != null)
                KeyedSubtree(
                  key: DataTableCard.llaveFiltros,
                  child: widget.seccionFiltros!,
                ),
              if (widget.pagination != null)
                KeyedSubtree(
                  key: DataTableCard.llavePaginacion,
                  child: widget.pagination!,
                ),
              AnimatedSize(
                key: DataTableCard.llaveLista,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _body(context, isSmall: isSmall, maxWidth: width),
              ),
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
      return _Marco(
        radio: _radio,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (widget.rows.isEmpty) {
      return _Marco(
        radio: _radio,
        child: _Vacio(mensaje: widget.emptyMessage),
      );
    }

    // Las tarjetas de la vista compacta ya tienen borde propio; enmarcarlas
    // otra vez sería una caja dentro de otra.
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

    return _Marco(
      radio: _radio,
      // El ancho de dentro del marco: el borde se queda con un píxel por lado,
      // y sin descontarlo la tabla pediría dos de más y nacería desplazable.
      child: _scrollableTable(context, maxWidth - 2),
    );
  }

  Widget _scrollableTable(BuildContext context, double maxWidth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final table = DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: widget.ascending,
      showCheckboxColumn: false,
      // Un renglón alto y sin líneas que lo encajonen: el rayado ya separa una
      // fila de la siguiente, y la línea encima del rayado ensuciaba la tabla.
      headingRowHeight: 56,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 60,
      horizontalMargin: 20,
      columnSpacing: 28,
      dividerThickness: 0,
      showBottomBorder: false,
      headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      headingTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      dataTextStyle: theme.textTheme.bodyMedium,
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

}

/// El nombre del listado y el botón de agregar, cerrados por una línea.
///
/// El botón vive aquí y no entre los filtros porque no acota la lista, la hace
/// crecer: puesto junto a ellos parecía uno más. La línea separa lo que el
/// listado es de lo que se hace con él.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    super.key,
    required this.titulo,
    required this.icono,
    required this.radio,
    this.addLabel,
    this.onAdd,
  });

  final String? titulo;
  final IconData? icono;
  final double radio;
  final String? addLabel;
  final VoidCallback? onAdd;

  /// Lo que separa el renglón del título de la línea de abajo.
  static const double _aire = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titulo = this.titulo;
    final addLabel = this.addLabel;

    final boton = addLabel == null
        ? null
        : _BotonAgregar(label: addLabel, onPressed: onAdd, radio: radio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo == null)
          // Sin nombre que poner, el botón se queda solo a la derecha: un
          // `Wrap` repartido lo dejaría pegado a la izquierda.
          Align(alignment: Alignment.centerRight, child: boton)
        else
          Wrap(
            // En una ventana angosta el botón no cabe al lado del nombre, y
            // baja al renglón siguiente en lugar de desbordarse.
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _Titulo(texto: titulo, icono: icono),
              ?boton,
            ],
          ),
        const SizedBox(height: _aire),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
      ],
    );
  }
}

/// El nombre del listado, con el icono con el que se le conoce en la
/// navegación.
class _Titulo extends StatelessWidget {
  const _Titulo({required this.texto, this.icono});

  final String texto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icono = this.icono;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (icono != null) Icon(icono, color: theme.colorScheme.primary),
        Text(
          texto,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// El botón que da de alta un registro del listado.
class _BotonAgregar extends StatelessWidget {
  const _BotonAgregar({
    required this.label,
    required this.radio,
    this.onPressed,
  });

  final String label;
  final double radio;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(IconsManager.add),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
    );
  }
}

/// El recuadro que encierra la lista.
///
/// Da a la tabla un contorno propio dentro de la tarjeta: sin él, los
/// encabezados y el rayado flotaban sobre el fondo y la lista no se distinguía
/// de los controles de arriba.
class _Marco extends StatelessWidget {
  const _Marco({required this.radio, required this.child});

  final double radio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Lo que se ve cuando no hay nada que listar.
class _Vacio extends StatelessWidget {
  const _Vacio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        spacing: 12,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 44,
            color: scheme.outline,
          ),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
