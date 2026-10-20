import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_column.dart';

/// El contenido de un listado: su encabezado, los filtros, la paginación y la
/// tabla.
///
/// La tabla es la misma a cualquier ancho. Antes, por debajo de cierto corte,
/// se cambiaba por una lista de tarjetas que escondía columnas: eran dos
/// listados que había que mantener a la par y que no enseñaban lo mismo. En
/// una ventana angosta la tabla se recorre a lo ancho, que es lo que ya hace
/// cuando sus columnas no caben.
///
/// De arriba abajo:
///
/// 1. el encabezado que arme la pantalla, cerrado por una línea;
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
/// Todas las celdas salen de [columns], acciones incluidas, así que la fila
/// siempre tiene tantas celdas como encabezados: no hay columnas que la tabla
/// agregue por su cuenta y que haya que recordar al contar.
///
/// Ordenar no es cosa de la tabla: lo elige el desplegable de los filtros
/// (`SortDropdown`). El encabezado también ordenaba, y eran dos mandos para lo
/// mismo: el del filtro ordena por cualquier columna, también por las que
/// quedan fuera de la parte visible cuando la tabla se recorre a lo ancho,
/// mientras que el encabezado sólo alcanza a las que se ven y le quitaba ancho
/// al nombre de cada columna para reservarle sitio a su flecha.
///
/// ```dart
/// DataTableCard<PrecioData>(
///   rows: precios,
///   seccionEncabezado: Wrap(
///     alignment: WrapAlignment.spaceBetween,
///     children: [
///       const PestanasCatalogo(),
///       ButtonAdd(label: 'Agregar concepto', onPressed: _onAgregar),
///     ],
///   ),
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
///     ),
///     TableColumnDef.text(
///       title: 'Importe',
///       value: (precio) => precio.importe.toStringAsFixed(2),
///       numeric: true,
///     ),
///     TableColumnDef.widget(
///       title: 'Acciones',
///       size: const TableColumnSize.fija(TableActionsCell.ancho),
///       content: (context, precio) => TableActionsCell(
///         actions: [
///           TableAction(
///             label: 'Editar concepto',
///             icon: Icons.edit,
///             color: Colors.blue,
///             onPressed: () => _onEditar(precio),
///           ),
///         ],
///       ),
///     ),
///   ],
/// )
/// ```
class DataTableCard<T> extends StatefulWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.rowKey,
    this.onRowTap,
    this.seccionEncabezado,
    this.seccionFiltros,
    this.isLoading = false,
    this.emptyMessage = 'No hay elementos disponibles',
    this.pagination,
  }) : assert(columns.length > 0, 'La tabla necesita al menos una columna');

  final List<TableColumnDef<T>> columns;
  final List<T> rows;

  /// Identidad de la fila. Con ella Flutter reconoce las filas entre dos
  /// consultas y no reconstruye las que no cambiaron.
  final Object Function(T row)? rowKey;
  final ValueChanged<T>? onRowTap;

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

  /// Lo que encabeza el listado: cómo se llama, en qué catálogo está uno, el
  /// botón de agregar... lo que la pantalla decida.
  ///
  /// La tarjeta no sabe qué lleva dentro: lo pone arriba del todo y le cierra
  /// con una línea. En `null` no hay encabezado ni línea, y la tarjeta empieza
  /// por los filtros.
  final Widget? seccionEncabezado;

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
  State<DataTableCard<T>> createState() => _DataTableCardState<T>();
}

class _DataTableCardState<T> extends State<DataTableCard<T>> {
  final ScrollController _horizontal = ScrollController();

  /// El aire entre los tres bloques: 1.5 rem.
  ///
  /// Es el mismo entre los controles y la paginación que entre la paginación y
  /// la lista, para que los tres se lean como tres cosas al mismo nivel y no
  /// como una pegada a otra.
  static const double _espacio = 24;

  /// Lo que separa el contenido del borde de la tarjeta.
  static const double _relleno = 20;

  @override
  void dispose() {
    // El controlador sobrevive al widget si no se cierra aquí.
    _horizontal.dispose();
    super.dispose();
  }

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

          return Column(
            spacing: _espacio,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.seccionEncabezado != null) ...[
                KeyedSubtree(
                  key: DataTableCard.llaveEncabezado,
                  child: widget.seccionEncabezado!,
                ),
                // La línea cierra el encabezado: separa lo que el listado es
                // —su nombre, lo que se hace con él— de lo que se hace con sus
                // filas. Va aquí y no dentro del encabezado para que se vea de
                // dónde sale el aire que la rodea.
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
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
                child: _Cuerpo<T>(
                  cargando: widget.isLoading,
                  filas: widget.rows,
                  columnas: widget.columns,
                  mensajeVacio: widget.emptyMessage,
                  ancho: width,
                  horizontal: _horizontal,
                  onRowTap: widget.onRowTap,
                  rowKey: widget.rowKey,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

/// La lista, el aviso de vacío o el indicador de carga: nunca dos a la vez,
/// que es lo que pasaba antes, cuando una lista vacía mostraba la tabla con
/// sólo encabezados y el mensaje debajo.
class _Cuerpo<T> extends StatelessWidget {
  const _Cuerpo({
    required this.cargando,
    required this.filas,
    required this.columnas,
    required this.mensajeVacio,
    required this.ancho,
    required this.horizontal,
    required this.onRowTap,
    required this.rowKey,
  });

  final bool cargando;
  final List<T> filas;
  final List<TableColumnDef<T>> columnas;
  final String mensajeVacio;

  /// El ancho que la tarjeta puede dar, ya medido.
  final double ancho;

  final ScrollController horizontal;
  final void Function(T row)? onRowTap;
  final Object Function(T row)? rowKey;

  /// El redondeo del recuadro que encierra la lista.
  static const double _radio = 16;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const _Marco(
        radio: _radio,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (filas.isEmpty) {
      return _Marco(radio: _radio, child: _Vacio(mensaje: mensajeVacio));
    }

    return _Marco(
      radio: _radio,
      // El ancho de dentro del marco: el borde se queda con un píxel por lado,
      // y sin descontarlo la tabla pediría dos de más y nacería desplazable.
      child: _Tabla<T>(
        columnas: columnas,
        filas: filas,
        ancho: ancho - 2,
        horizontal: horizontal,
        onRowTap: onRowTap,
        rowKey: rowKey,
      ),
    );
  }
}

/// La tabla, que se recorre a lo ancho cuando sus columnas no caben.
class _Tabla<T> extends StatelessWidget {
  const _Tabla({
    required this.columnas,
    required this.filas,
    required this.ancho,
    required this.horizontal,
    required this.onRowTap,
    required this.rowKey,
  });

  final List<TableColumnDef<T>> columnas;
  final List<T> filas;

  /// El ancho de dentro del marco.
  final double ancho;

  final ScrollController horizontal;
  final void Function(T row)? onRowTap;
  final Object Function(T row)? rowKey;

  /// Lo que separa el contenido de las orillas de la tabla.
  static const double _margen = 16;

  /// El aire entre una columna y la siguiente.
  static const double _espacioColumnas = 16;

  /// El alto del renglón de encabezados: dos renglones de texto y su aire.
  static const double _altoEncabezado = 56;

  /// Lo que la tabla necesita para no apretar ninguna columna.
  ///
  /// Es la suma de los mínimos de sus columnas —el aire de cada celda va
  /// dentro—, y es el ancho con el que la tabla se dibuja cuando la ventana da
  /// menos: a partir de ahí se desplaza en lugar de seguir encogiendo, que es
  /// lo que dejaba los datos ilegibles.
  double get _anchoMinimo {
    var minimo = 0.0;

    for (final columna in columnas) {
      minimo += columna.anchoMinimo;
    }

    return minimo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final table = DataTable(
      showCheckboxColumn: false,
      // Un renglón alto y sin líneas que lo encajonen: el rayado ya separa una
      // fila de la siguiente, y la línea encima del rayado ensuciaba la tabla.
      headingRowHeight: _altoEncabezado,
      dataRowMinHeight: 52,
      // Sin tope de alto: una celda cuyo texto no cabe a lo ancho baja de
      // línea, y la fila crece con ella. Con un máximo fijo, el texto que
      // sobraba quedaba cortado por la mitad.
      dataRowMaxHeight: double.infinity,
      horizontalMargin: _margen,
      columnSpacing: _espacioColumnas,
      dividerThickness: 0,
      showBottomBorder: false,
      // El encabezado va del color de la acción principal, el mismo lleno del
      // botón de agregar: una banda que dice dónde empieza la lista y separa
      // los nombres de las columnas de los datos sin necesidad de una línea.
      headingRowColor: WidgetStatePropertyAll(scheme.primary),
      headingTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      dataTextStyle: theme.textTheme.bodyMedium,
      columns: _encabezados(),
      rows: _renglones(context),
    );

    return Scrollbar(
      controller: horizontal,
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
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          // El ancho se decide aquí y no se deja al contenido: con el de la
          // tarjeta, las columnas se reparten lo que hay y la tabla no se
          // desplaza; cuando la ventana no llega al mínimo, la tabla se queda
          // en ese mínimo y lo que sobra se recorre.
          //
          // Antes esto era un `minWidth` dentro de un desplazable, de modo que
          // la tabla se medía con ancho infinito: cada columna pedía lo que
          // midiera su texto más largo y casi siempre había que desplazarse,
          // aunque sobrara sitio en la pantalla.
          child: SizedBox(
            width: math.max(ancho, _anchoMinimo),
            child: table,
          ),
        ),
      ),
    );
  }

  /// Los encabezados.
  ///
  /// Sigue siendo un método y no un widget porque `DataColumn` no lo es: es la
  /// configuración que `DataTable` pide, y lo único que sí es un widget —el
  /// nombre de la columna— ya va dentro.
  List<DataColumn> _encabezados() {
    return [
      for (final columna in columnas)
        DataColumn(
          numeric: columna.numeric,
          tooltip: columna.tooltip,
          columnWidth: columna.columnWidth,
          // Expanded y no Flexible: el nombre se queda con la columna entera.
          // `DataTable` le reservaba 36 píxeles a la flecha de ordenamiento
          // —16 de flecha, 2 de aire y otros 18 del lado contrario para
          // centrarlo entre los dos—, más de un tercio de la columna más
          // angosta, y por eso "Tamaño" se partía en dos renglones teniendo
          // sitio de sobra.
          //
          // `softWrap` va explícito porque `DataTable` lo apaga en los
          // encabezados: sin esto, "Fecha de Eliminación" se queda en un
          // renglón y se corta. Dos líneas es lo que cabe en el alto del
          // encabezado.
          label: Expanded(
            child: Text(
              columna.title,
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
            ),
          ),
        ),
    ];
  }

  /// Las filas, también configuración de `DataTable`. Lo que cada celda
  /// enseña lo arma [TableCellContent], que sí es un widget.
  List<DataRow> _renglones(BuildContext context) {
    final stripes = ColorRowTheme.of(context);
    final onRowTap = this.onRowTap;
    final rowKey = this.rowKey;

    return [
      for (final (index, fila) in filas.indexed)
        DataRow(
          key: rowKey == null ? null : ValueKey(rowKey(fila)),
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return stripes.hoverColor;
            return stripes.colorForRow(index);
          }),
          onSelectChanged: onRowTap == null ? null : (_) => onRowTap(fila),
          mouseCursor: WidgetStatePropertyAll(
            onRowTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
          ),
          cells: [
            for (final columna in columnas)
              DataCell(
                Padding(
                  // El aire de arriba y abajo lo pone la celda: sin él, un
                  // texto que baja de línea queda pegado al borde de la fila.
                  // En una celda de un renglón no se nota, porque la fila
                  // tiene un alto mínimo mayor.
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Align(
                    alignment: columna.numeric
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: TableCellContent<T>(columna: columna, fila: fila),
                  ),
                ),
              ),
          ],
        ),
    ];
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
