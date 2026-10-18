import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_alignment.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_breakpoint.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_row.dart';

/// Cuántas de las doce columnas de la rejilla ocupa algo, y desde qué ancho.
///
/// Es el `<v-col>` de Vuetify: se envuelve el contenido y se dice cuánto mide
/// en cada punto de quiebre. Lo declarado en uno vale desde ahí hacia arriba,
/// así que `VCol(cols: 12, md: 6, lg: 3)` ocupa la fila entera en una ventana
/// angosta, media desde `md` y un cuarto desde `lg`.
///
/// ```dart
/// VRow(
///   children: [
///     VCol(cols: 12, md: 4, child: Buscador()),
///     VCol(cols: 6, md: VCol.grow, child: FiltroEstatus()),
///     VCol(cols: 6, md: VCol.auto, child: BotonLimpiar()),
///   ],
/// )
/// ```
///
/// Los tres tamaños posibles, igual que en Vuetify:
///
/// * un número de 1 a 12 —el `cols="6"` de la web—: una fracción fija del
///   ancho de la fila;
/// * [auto] —`cols="auto"`—: lo que mida su contenido;
/// * [grow], que es lo de omisión —`<v-col>` sin `cols`—: una parte igual de
///   lo que sobre.
///
/// [minWidth] y [maxWidth] no son atributos de Vuetify, pero sí son el
/// `min-width`/`max-width` de CSS que hay detrás, y aquí hacen falta: en la
/// web una columna no se encoge por debajo de lo que mide su contenido, y
/// averiguar eso en Flutter obliga a medir al hijo, algo que un
/// `LayoutBuilder` dentro del hijo no permite. Con [minWidth] se dice ese
/// mínimo a mano: la columna no baja de ahí y, si no cabe, el renglón se
/// parte.
class VCol extends ParentDataWidget<VColParentData> {
  const VCol({
    super.key,
    this.cols,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
    this.offset,
    this.offsetSm,
    this.offsetMd,
    this.offsetLg,
    this.offsetXl,
    this.offsetXxl,
    this.order,
    this.orderSm,
    this.orderMd,
    this.orderLg,
    this.orderXl,
    this.orderXxl,
    this.alignSelf,
    this.minWidth,
    this.maxWidth,
    required super.child,
  }) : assert(cols == null || cols >= auto, _errorTamano),
       assert(sm == null || sm >= auto, _errorTamano),
       assert(md == null || md >= auto, _errorTamano),
       assert(lg == null || lg >= auto, _errorTamano),
       assert(xl == null || xl >= auto, _errorTamano),
       assert(xxl == null || xxl >= auto, _errorTamano),
       assert(offset == null || offset >= 0, _errorDesplazamiento),
       assert(offsetSm == null || offsetSm >= 0, _errorDesplazamiento),
       assert(offsetMd == null || offsetMd >= 0, _errorDesplazamiento),
       assert(offsetLg == null || offsetLg >= 0, _errorDesplazamiento),
       assert(offsetXl == null || offsetXl >= 0, _errorDesplazamiento),
       assert(offsetXxl == null || offsetXxl >= 0, _errorDesplazamiento),
       assert(minWidth == null || minWidth >= 0, _errorAncho),
       assert(maxWidth == null || maxWidth >= 0, _errorAncho),
       assert(
         minWidth == null || maxWidth == null || minWidth <= maxWidth,
         'El ancho mínimo de una columna no puede pasar del máximo',
       );

  /// La columna mide lo que mida su contenido: el `cols="auto"` de Vuetify.
  static const int auto = -1;

  /// La columna se reparte el hueco sobrante con las demás que crecen.
  ///
  /// Es lo que hace un `<v-col>` sin `cols`, y por eso es lo de omisión: una
  /// columna sin tamaño declarado crece.
  static const int grow = 0;

  static const String _errorTamano =
      'El tamaño de una columna es un número de 1 a 12, VCol.auto o VCol.grow';
  static const String _errorDesplazamiento =
      'El desplazamiento de una columna se cuenta en columnas, nunca negativo';
  static const String _errorAncho = 'El ancho de una columna no es negativo';

  /// El tamaño desde el ancho cero: el que vale mientras no haya otro mayor.
  final int? cols;
  final int? sm;
  final int? md;
  final int? lg;
  final int? xl;
  final int? xxl;

  /// Cuántas columnas se dejan vacías antes de ésta.
  final int? offset;
  final int? offsetSm;
  final int? offsetMd;
  final int? offsetLg;
  final int? offsetXl;
  final int? offsetXxl;

  /// En qué lugar se coloca dentro de la fila.
  ///
  /// Las columnas se ordenan de menor a mayor y las que no lo dicen valen
  /// cero, así que un `order: -1` adelanta y un `order: 1` atrasa. Entre
  /// iguales se respeta el orden en que se escribieron.
  final int? order;
  final int? orderSm;
  final int? orderMd;
  final int? orderLg;
  final int? orderXl;
  final int? orderXxl;

  /// Rompe la alineación a lo alto que puso la fila, sólo para esta columna.
  final VAlign? alignSelf;

  /// Lo que la columna no baja aunque le toque menos al repartir.
  ///
  /// También decide cuándo se parte el renglón: una columna que no cabe con su
  /// mínimo se va a la siguiente línea en lugar de aplastar a las demás.
  final double? minWidth;

  /// Lo que la columna no pasa aunque sobre espacio.
  final double? maxWidth;

  /// Lo que de esta columna necesita la fila para repartir el ancho.
  VColSpec get spec => VColSpec(
    spans: [cols, sm, md, lg, xl, xxl],
    offsets: [offset, offsetSm, offsetMd, offsetLg, offsetXl, offsetXxl],
    orders: [order, orderSm, orderMd, orderLg, orderXl, orderXxl],
    alignSelf: alignSelf,
    minWidth: minWidth,
    maxWidth: maxWidth,
  );

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as VColParentData;
    final spec = this.spec;

    if (parentData.spec == spec) return;

    parentData.spec = spec;

    // Cambiar el tamaño de una columna vuelve a repartir el ancho de toda la
    // fila, así que a quien hay que avisar es al padre y no al hijo.
    final padre = renderObject.parent;
    if (padre is RenderObject) padre.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => VRow;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('cols', cols, defaultValue: null))
      ..add(IntProperty('sm', sm, defaultValue: null))
      ..add(IntProperty('md', md, defaultValue: null))
      ..add(IntProperty('lg', lg, defaultValue: null))
      ..add(IntProperty('xl', xl, defaultValue: null))
      ..add(IntProperty('xxl', xxl, defaultValue: null))
      ..add(IntProperty('offset', offset, defaultValue: null))
      ..add(IntProperty('order', order, defaultValue: null))
      ..add(EnumProperty<VAlign>('alignSelf', alignSelf, defaultValue: null))
      ..add(DoubleProperty('minWidth', minWidth, defaultValue: null))
      ..add(DoubleProperty('maxWidth', maxWidth, defaultValue: null));
  }
}

/// Lo que una columna le dice a su fila, ya sin forma de widget.
///
/// Guarda un valor por punto de quiebre —en el orden de [VBreakpoint]— y los
/// resuelve en cascada: se pregunta por el punto activo y, si ahí no se
/// declaró nada, se va bajando hasta encontrar el último declarado.
@immutable
class VColSpec {
  const VColSpec({
    this.spans = _sinDeclarar,
    this.offsets = _sinDeclarar,
    this.orders = _sinDeclarar,
    this.alignSelf,
    this.minWidth,
    this.maxWidth,
  });

  static const List<int?> _sinDeclarar = [null, null, null, null, null, null];

  final List<int?> spans;
  final List<int?> offsets;
  final List<int?> orders;
  final VAlign? alignSelf;
  final double? minWidth;
  final double? maxWidth;

  /// El tamaño que vale en [punto], o `null` si no se declaró ninguno.
  int? spanAt(VBreakpoint punto) => _enCascada(spans, punto);

  /// Las columnas que se dejan vacías antes de ésta, en [punto].
  int offsetAt(VBreakpoint punto) => _enCascada(offsets, punto) ?? 0;

  /// El lugar que ocupa dentro de la fila, en [punto].
  int orderAt(VBreakpoint punto) => _enCascada(orders, punto) ?? 0;

  static int? _enCascada(List<int?> valores, VBreakpoint punto) {
    for (var i = punto.index; i >= 0; i--) {
      final valor = valores[i];
      if (valor != null) return valor;
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VColSpec &&
        listEquals(other.spans, spans) &&
        listEquals(other.offsets, offsets) &&
        listEquals(other.orders, orders) &&
        other.alignSelf == alignSelf &&
        other.minWidth == minWidth &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(spans),
    Object.hashAll(offsets),
    Object.hashAll(orders),
    alignSelf,
    minWidth,
    maxWidth,
  );
}

/// Lo que la fila anota en cada hijo para poder repartir el ancho.
class VColParentData extends ContainerBoxParentData<RenderBox> {
  /// De omisión, la de un hijo que no viene envuelto en [VCol]: una columna
  /// que crece, como el `<v-col>` pelado de Vuetify.
  VColSpec spec = const VColSpec();
}
