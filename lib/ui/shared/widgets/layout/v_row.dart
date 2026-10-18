import 'package:flutter/widgets.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/render_v_row.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_alignment.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_breakpoint.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_col.dart';

/// Una fila de la rejilla de doce columnas: el `<v-row>` de Vuetify.
///
/// Reparte su ancho entre los [VCol] que lleva dentro y los pasa al renglón
/// siguiente cuando no caben, con el mismo aire entre columnas que entre
/// renglones.
///
/// ```dart
/// VRow(
///   align: VAlign.center,
///   children: [
///     VCol(cols: 12, md: 4, child: Buscador()),
///     VCol(cols: 6, md: VCol.grow, child: FiltroEstatus()),
///     VCol(cols: 6, md: VCol.auto, child: BotonLimpiar()),
///   ],
/// )
/// ```
///
/// Un hijo que no venga envuelto en [VCol] cuenta como una columna que crece,
/// igual que un `<v-col>` sin atributos.
///
/// Dos diferencias con la web, las dos a propósito:
///
/// * el punto de quiebre se mide con el ancho que la fila recibe y no con el
///   de la ventana —véase [VBreakpointSource]—, porque una fila dentro de un
///   panel angosto tiene que partirse aunque el monitor sea grande;
/// * una columna no se encoge sola hasta lo que mide su contenido: eso se
///   dice con `VCol.minWidth`, porque medir al hijo no siempre es posible
///   —un `LayoutBuilder` dentro de él lo impide— y hacerlo a escondidas
///   rompería controles que sí lo llevan.
class VRow extends MultiChildRenderObjectWidget {
  const VRow({
    super.key,
    this.gutter,
    this.gutterX,
    this.gutterY,
    this.noGutters = false,
    this.dense = false,
    this.density = VDensity.standard,
    this.align,
    this.alignSm,
    this.alignMd,
    this.alignLg,
    this.alignXl,
    this.alignXxl,
    this.justify,
    this.justifySm,
    this.justifyMd,
    this.justifyLg,
    this.justifyXl,
    this.justifyXxl,
    this.alignContent,
    this.alignContentSm,
    this.alignContentMd,
    this.alignContentLg,
    this.alignContentXl,
    this.alignContentXxl,
    this.columns = 12,
    this.breakpointSource = VBreakpointSource.container,
    super.children,
  }) : assert(columns > 0, 'La rejilla necesita al menos una columna'),
       assert(gutter == null || gutter >= 0, _errorCanalon),
       assert(gutterX == null || gutterX >= 0, _errorCanalon),
       assert(gutterY == null || gutterY >= 0, _errorCanalon);

  static const String _errorCanalon =
      'El aire entre columnas no puede ser negativo';

  /// El aire entre columnas y entre renglones, cuando no vale el de la
  /// densidad.
  final double? gutter;

  /// El aire sólo entre columnas, si tiene que ser distinto del de abajo.
  final double? gutterX;

  /// El aire sólo entre renglones.
  final double? gutterY;

  /// Pega las columnas unas con otras.
  final bool noGutters;

  /// Atajo de [VDensity.compact], como el `dense` de Vuetify.
  final bool dense;

  /// Cuánto aire deja la fila, cuando no se dice uno a mano.
  final VDensity density;

  /// Cómo se alinean las columnas a lo alto de su renglón.
  ///
  /// Sin decir nada se estiran todas hasta la más alta, que es lo que hace un
  /// contenedor flexible en la web. [VAlign.center] es lo que deja un botón y
  /// un campo de texto a la misma altura.
  final VAlign? align;
  final VAlign? alignSm;
  final VAlign? alignMd;
  final VAlign? alignLg;
  final VAlign? alignXl;
  final VAlign? alignXxl;

  /// Cómo se reparte el hueco que sobra a lo ancho del renglón.
  final VJustify? justify;
  final VJustify? justifySm;
  final VJustify? justifyMd;
  final VJustify? justifyLg;
  final VJustify? justifyXl;
  final VJustify? justifyXxl;

  /// Cómo se reparten los renglones cuando a la fila le sobra alto.
  final VAlignContent? alignContent;
  final VAlignContent? alignContentSm;
  final VAlignContent? alignContentMd;
  final VAlignContent? alignContentLg;
  final VAlignContent? alignContentXl;
  final VAlignContent? alignContentXxl;

  /// En cuántas partes se divide el ancho. Doce, como en la web, salvo que
  /// una pantalla pida otra cosa.
  final int columns;

  /// Con qué ancho se elige el punto de quiebre.
  final VBreakpointSource breakpointSource;

  @override
  RenderVRow createRenderObject(BuildContext context) {
    return RenderVRow(
      gutterX: _aireHorizontal,
      gutterY: _aireVertical,
      columns: columns,
      textDirection: _direccion(context),
      align: _alineaciones,
      justify: _repartos,
      alignContent: _alineacionesDeRenglon,
      viewportWidth: _anchoDeVentana(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderVRow renderObject) {
    renderObject
      ..gutterX = _aireHorizontal
      ..gutterY = _aireVertical
      ..columns = columns
      ..textDirection = _direccion(context)
      ..align = _alineaciones
      ..justify = _repartos
      ..alignContent = _alineacionesDeRenglon
      ..viewportWidth = _anchoDeVentana(context);
  }

  /// La densidad que acaba valiendo: `dense` es el nombre viejo de la
  /// compacta y gana si se pide, como en Vuetify.
  VDensity get _densidad => dense ? VDensity.compact : density;

  double get _aireHorizontal =>
      noGutters ? 0 : (gutterX ?? gutter ?? _densidad.gutter);

  double get _aireVertical =>
      noGutters ? 0 : (gutterY ?? gutter ?? _densidad.gutter);

  List<VAlign?> get _alineaciones => [
    align,
    alignSm,
    alignMd,
    alignLg,
    alignXl,
    alignXxl,
  ];

  List<VJustify?> get _repartos => [
    justify,
    justifySm,
    justifyMd,
    justifyLg,
    justifyXl,
    justifyXxl,
  ];

  List<VAlignContent?> get _alineacionesDeRenglon => [
    alignContent,
    alignContentSm,
    alignContentMd,
    alignContentLg,
    alignContentXl,
    alignContentXxl,
  ];

  /// El ancho de la ventana sólo se consulta cuando es el que manda: así la
  /// fila no se vuelve a armar cada vez que la ventana cambia de tamaño si lo
  /// que la rige es su propio ancho.
  double? _anchoDeVentana(BuildContext context) =>
      breakpointSource == VBreakpointSource.viewport
      ? MediaQuery.sizeOf(context).width
      : null;

  /// Hacia dónde crece la fila. Sin nadie que lo diga, de izquierda a
  /// derecha.
  TextDirection _direccion(BuildContext context) =>
      Directionality.maybeOf(context) ?? TextDirection.ltr;
}
