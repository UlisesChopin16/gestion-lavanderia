// El analizador pide aquí lo que el lenguaje no deja: los campos de un
// `RenderObject` son privados —se escriben por sus setters, que avisan de que
// hay que volver a disponer la fila— y un parámetro con nombre no puede
// empezar por guión bajo, así que `this._gutterX` no compila.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_alignment.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_breakpoint.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/v_col.dart';

/// La rejilla de doce columnas, repartiendo el ancho entre sus hijos.
///
/// Hace lo que hace un contenedor flexible de la web —`display: flex` con
/// `flex-wrap: wrap`— acotado a lo que necesita una rejilla:
///
/// 1. cada columna pide un ancho base: una fracción del total si declaró
///    tamaño, lo que mida su contenido si es [VCol.auto], o nada si crece;
/// 2. las columnas se van metiendo en el renglón mientras quepan con ese
///    ancho, y la que no cabe abre el siguiente;
/// 3. dentro de cada renglón, lo que sobra se reparte en partes iguales entre
///    las columnas que crecen, sin que ninguna baje de su mínimo ni pase de su
///    máximo;
/// 4. cada renglón mide lo que su columna más alta y se alinean dentro de él.
///
/// No es un [RenderFlex] con [RenderWrap] encima porque ninguno de los dos
/// sabe de fracciones del ancho del padre: `Expanded` reparte lo que sobra,
/// no un doceavo del total, y `Wrap` no estira a sus hijos. La diferencia se
/// ve en cuanto hay dos columnas con tamaños distintos en el mismo renglón.
class RenderVRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, VColParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, VColParentData> {
  RenderVRow({
    List<RenderBox>? children,
    required double gutterX,
    required double gutterY,
    required int columns,
    required TextDirection textDirection,
    required List<VAlign?> align,
    required List<VJustify?> justify,
    required List<VAlignContent?> alignContent,
    double? viewportWidth,
  }) : _gutterX = gutterX,
       _gutterY = gutterY,
       _columns = columns,
       _textDirection = textDirection,
       _align = align,
       _justify = justify,
       _alignContent = alignContent,
       _viewportWidth = viewportWidth {
    addAll(children);
  }

  /// Lo que se le perdona a un renglón antes de partirlo.
  ///
  /// Doce columnas de un doceavo suman el ancho entero, pero sumadas una a una
  /// en coma flotante pueden pasarse por una millonésima de píxel. Sin este
  /// margen, la última se iría al renglón siguiente por algo que nadie puede
  /// ver.
  static const double _tolerancia = 0.01;

  double _gutterX;
  double get gutterX => _gutterX;
  set gutterX(double value) {
    if (_gutterX == value) return;
    _gutterX = value;
    markNeedsLayout();
  }

  double _gutterY;
  double get gutterY => _gutterY;
  set gutterY(double value) {
    if (_gutterY == value) return;
    _gutterY = value;
    markNeedsLayout();
  }

  int _columns;
  int get columns => _columns;
  set columns(int value) {
    if (_columns == value) return;
    _columns = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  List<VAlign?> _align;
  List<VAlign?> get align => _align;
  set align(List<VAlign?> value) {
    if (listEquals(_align, value)) return;
    _align = value;
    markNeedsLayout();
  }

  List<VJustify?> _justify;
  List<VJustify?> get justify => _justify;
  set justify(List<VJustify?> value) {
    if (listEquals(_justify, value)) return;
    _justify = value;
    markNeedsLayout();
  }

  List<VAlignContent?> _alignContent;
  List<VAlignContent?> get alignContent => _alignContent;
  set alignContent(List<VAlignContent?> value) {
    if (listEquals(_alignContent, value)) return;
    _alignContent = value;
    markNeedsLayout();
  }

  /// El ancho de la ventana, cuando el punto de quiebre se mide con él en
  /// lugar de con el ancho de la fila. En `null` manda el de la fila.
  double? _viewportWidth;
  double? get viewportWidth => _viewportWidth;
  set viewportWidth(double? value) {
    if (_viewportWidth == value) return;
    _viewportWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! VColParentData) {
      child.parentData = VColParentData();
    }
  }

  @override
  void performLayout() {
    size = _repartir(constraints, seco: false).size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _repartir(constraints, seco: true).size;

  /// El ancho mínimo: el de la columna más exigente.
  ///
  /// No se escalan los tamaños declarados —un `cols: 3` pediría cuatro veces
  /// lo que mida su hijo— porque el tamaño depende del punto de quiebre y el
  /// punto de quiebre depende del ancho, que es justo lo que aquí se está
  /// preguntando.
  @override
  double computeMinIntrinsicWidth(double height) {
    var minimo = 0.0;

    for (var hijo = firstChild; hijo != null; hijo = _siguiente(hijo)) {
      minimo = math.max(minimo, hijo.getMinIntrinsicWidth(height));
    }

    return minimo;
  }

  /// El ancho al que todas las columnas caben en un solo renglón.
  @override
  double computeMaxIntrinsicWidth(double height) {
    var total = 0.0;
    var cuantas = 0;

    for (var hijo = firstChild; hijo != null; hijo = _siguiente(hijo)) {
      total += hijo.getMaxIntrinsicWidth(height);
      cuantas++;
    }

    return cuantas < 2 ? total : total + gutterX * (cuantas - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _altoCon(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _altoCon(width);

  double _altoCon(double width) =>
      _repartir(BoxConstraints.tightFor(width: width), seco: true).size.height;

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('gutterX', gutterX))
      ..add(DoubleProperty('gutterY', gutterY))
      ..add(IntProperty('columns', columns))
      ..add(EnumProperty<TextDirection>('textDirection', textDirection))
      ..add(DoubleProperty('viewportWidth', viewportWidth, defaultValue: null));
  }

  /// Reparte el ancho entre las columnas y, si no es un cálculo [seco],
  /// coloca a cada una en su sitio.
  ///
  /// Un cálculo seco sólo mide: no mueve a los hijos ni los dispone, porque
  /// Flutter lo usa para preguntar cuánto ocuparía la fila sin llegar a
  /// armarla.
  _Reparto _repartir(BoxConstraints constraints, {required bool seco}) {
    final hijos = <RenderBox>[];
    for (var hijo = firstChild; hijo != null; hijo = _siguiente(hijo)) {
      hijos.add(hijo);
    }

    if (hijos.isEmpty) return _Reparto(constraints.smallest);

    final acotado = constraints.hasBoundedWidth;
    final disponible = acotado ? constraints.maxWidth : double.infinity;
    final punto = VBreakpoint.of(
      _viewportWidth ?? (acotado ? disponible : 0),
    );

    // El orden declarado manda sobre el orden en que se escribieron, y entre
    // columnas con el mismo orden gana la que se escribió antes: por eso una
    // ordenación estable y no `List.sort`, que no lo es.
    mergeSort<RenderBox>(
      hijos,
      compare: (a, b) =>
          _spec(a).orderAt(punto).compareTo(_spec(b).orderAt(punto)),
    );

    final columnas = [
      for (final hijo in hijos)
        _medir(hijo, punto: punto, disponible: disponible, acotado: acotado),
    ];

    final renglones = _partirEnRenglones(columnas, disponible);

    for (final renglon in renglones) {
      if (acotado) {
        _repartirAncho(renglon.columnas, disponible);
      } else {
        for (final columna in renglon.columnas) {
          columna.ancho = columna.hipotetico;
        }
      }
    }

    _medirAlto(renglones, punto: punto, seco: seco);

    var contenido = gutterY * (renglones.length - 1);
    for (final renglon in renglones) {
      contenido += renglon.alto;
    }

    final ancho = acotado
        ? disponible
        : renglones.fold<double>(0, (mayor, renglon) {
            return math.max(mayor, _anchoUsado(renglon.columnas));
          });

    final size = constraints.constrain(Size(ancho, contenido));

    if (!seco) _colocar(renglones, size: size, contenido: contenido, punto: punto);

    return _Reparto(size);
  }

  /// Lo que una columna pide antes de repartir: su ancho base, su mínimo, su
  /// máximo y si crece.
  _Columna _medir(
    RenderBox hijo, {
    required VBreakpoint punto,
    required double disponible,
    required bool acotado,
  }) {
    final spec = _spec(hijo);
    final span = spec.spanAt(punto) ?? VCol.grow;

    // El máximo nunca pasa del ancho de la fila —el `max-width: 100%` que
    // llevan las columnas en la web— y el mínimo nunca pasa del máximo: una
    // columna que no cabe se queda del ancho de la fila en lugar de salirse.
    final maximo = math.min(spec.maxWidth ?? double.infinity, disponible);
    final minimo = math.min(spec.minWidth ?? 0, maximo);

    // Sin ancho conocido no hay fracciones que repartir: cada columna se
    // queda del tamaño de su contenido y la fila mide lo que sumen.
    if (!acotado) {
      return _Columna(
        child: hijo,
        spec: spec,
        base: hijo.getMaxIntrinsicWidth(double.infinity),
        minimo: minimo,
        maximo: maximo,
        desplazamiento: 0,
        crece: false,
      );
    }

    final double base;
    final bool crece;

    if (span == VCol.grow) {
      base = 0;
      crece = true;
    } else if (span == VCol.auto) {
      base = hijo.getMaxIntrinsicWidth(double.infinity);
      crece = false;
    } else {
      // La misma cuenta que hace Vuetify: la fracción se saca del ancho más
      // un canalón y se le quita uno, para que las columnas de un renglón
      // sumen el ancho justo con los canalones que llevan en medio.
      base = span * (disponible + gutterX) / columns - gutterX;
      crece = false;
    }

    return _Columna(
      child: hijo,
      spec: spec,
      base: base,
      minimo: minimo,
      maximo: maximo,
      desplazamiento:
          spec.offsetAt(punto) * (disponible + gutterX) / columns,
      crece: crece,
    );
  }

  /// Mete las columnas en renglones: cada una entra en el de arriba mientras
  /// quepa con el ancho que pidió.
  List<_Renglon> _partirEnRenglones(
    List<_Columna> columnas,
    double disponible,
  ) {
    final renglones = <_Renglon>[];
    var actual = <_Columna>[];
    var usado = 0.0;

    for (final columna in columnas) {
      final necesita = columna.desplazamiento + columna.hipotetico;
      final aire = actual.isEmpty ? 0.0 : gutterX;

      if (actual.isNotEmpty && usado + aire + necesita > disponible + _tolerancia) {
        renglones.add(_Renglon(actual));
        actual = [];
        usado = necesita;
      } else {
        usado += aire + necesita;
      }

      actual.add(columna);
    }

    if (actual.isNotEmpty) renglones.add(_Renglon(actual));

    return renglones;
  }

  /// Reparte lo que sobra del renglón entre las columnas que crecen.
  ///
  /// Se reparte en partes iguales; la que se quede corta de su mínimo —o se
  /// pase de su máximo— se queda en él y se vuelve a repartir entre las
  /// demás, que es como resuelve esto un contenedor flexible de la web.
  void _repartirAncho(List<_Columna> columnas, double disponible) {
    var libre = disponible - gutterX * (columnas.length - 1);
    final crecen = <_Columna>[];

    for (final columna in columnas) {
      libre -= columna.desplazamiento;

      if (columna.crece) {
        crecen.add(columna);
      } else {
        columna.ancho = columna.hipotetico;
        libre -= columna.ancho;
      }
    }

    if (crecen.isEmpty) return;

    final pendientes = crecen.toList();
    var resto = libre;

    while (pendientes.isNotEmpty) {
      final parte = resto / pendientes.length;
      final pasadas = [
        for (final columna in pendientes)
          if (parte < columna.minimo || parte > columna.maximo) columna,
      ];

      if (pasadas.isEmpty) {
        for (final columna in pendientes) {
          columna.ancho = parte;
        }
        return;
      }

      for (final columna in pasadas) {
        columna.ancho = parte < columna.minimo ? columna.minimo : columna.maximo;
        resto -= columna.ancho;
        pendientes.remove(columna);
      }
    }
  }

  /// Mide cada columna con el ancho que le tocó y da a su renglón el alto de
  /// la más alta.
  void _medirAlto(
    List<_Renglon> renglones, {
    required VBreakpoint punto,
    required bool seco,
  }) {
    for (final renglon in renglones) {
      var alto = 0.0;
      var ascenso = 0.0;
      var descenso = 0.0;

      for (final columna in renglon.columnas) {
        final restriccion = BoxConstraints.tightFor(width: columna.ancho);
        final size = seco
            ? ChildLayoutHelper.dryLayoutChild(columna.child, restriccion)
            : ChildLayoutHelper.layoutChild(columna.child, restriccion);

        columna.alto = size.height;
        alto = math.max(alto, size.height);

        if (_alineacionDe(columna, punto) != VAlign.baseline) continue;

        // La línea base sólo se puede preguntar sobre un hijo ya dispuesto,
        // así que en un cálculo seco se usa su alto y la fila queda, a lo
        // sumo, un poco más alta de lo que acabará siendo.
        columna.ascenso = seco
            ? size.height
            : columna.child.getDistanceToBaseline(
                    TextBaseline.alphabetic,
                    onlyReal: true,
                  ) ??
                  size.height;

        ascenso = math.max(ascenso, columna.ascenso);
        descenso = math.max(descenso, size.height - columna.ascenso);
      }

      renglon
        ..alto = math.max(alto, ascenso + descenso)
        ..ascenso = ascenso;
    }
  }

  /// Coloca cada columna: reparte a lo ancho lo que sobró del renglón y a lo
  /// alto lo que sobró de la fila.
  void _colocar(
    List<_Renglon> renglones, {
    required Size size,
    required double contenido,
    required VBreakpoint punto,
  }) {
    final sobraAlto = math.max(0.0, size.height - contenido);
    final (inicioY, entreRenglones, crecimiento) = _repartoVertical(
      sobraAlto,
      renglones.length,
      punto,
    );

    var y = inicioY;

    for (final renglon in renglones) {
      final altoRenglon = renglon.alto + crecimiento;
      final sobraAncho = math.max(0.0, size.width - _anchoUsado(renglon.columnas));
      final (inicioX, entreColumnas) = _repartoHorizontal(
        sobraAncho,
        renglon.columnas.length,
        punto,
      );

      var x = inicioX;

      for (final columna in renglon.columnas) {
        x += columna.desplazamiento;

        final alineacion = _alineacionDe(columna, punto);

        if (alineacion == VAlign.stretch && columna.alto != altoRenglon) {
          columna.child.layout(
            BoxConstraints.tightFor(width: columna.ancho, height: altoRenglon),
            parentUsesSize: true,
          );
          columna.alto = altoRenglon;
        }

        final dy = switch (alineacion) {
          VAlign.start || VAlign.stretch => 0.0,
          VAlign.center => (altoRenglon - columna.alto) / 2,
          VAlign.end => altoRenglon - columna.alto,
          VAlign.baseline => renglon.ascenso - columna.ascenso,
        };

        final parentData = columna.child.parentData! as VColParentData;
        parentData.offset = Offset(
          textDirection == TextDirection.ltr
              ? x
              : size.width - x - columna.ancho,
          y + dy,
        );

        x += columna.ancho + gutterX + entreColumnas;
      }

      y += altoRenglon + gutterY + entreRenglones;
    }
  }

  /// Dónde empieza el renglón y cuánto aire va entre sus columnas.
  (double inicio, double entre) _repartoHorizontal(
    double sobra,
    int cuantas,
    VBreakpoint punto,
  ) {
    return switch (_enCascada(_justify, punto) ?? VJustify.start) {
      VJustify.start => (0, 0),
      VJustify.center => (sobra / 2, 0),
      VJustify.end => (sobra, 0),
      VJustify.spaceBetween => cuantas > 1 ? (0, sobra / (cuantas - 1)) : (0, 0),
      VJustify.spaceAround => (sobra / cuantas / 2, sobra / cuantas),
      VJustify.spaceEvenly => (sobra / (cuantas + 1), sobra / (cuantas + 1)),
    };
  }

  /// Dónde empieza el primer renglón, cuánto aire va entre renglones y cuánto
  /// crece cada uno.
  (double inicio, double entre, double crecimiento) _repartoVertical(
    double sobra,
    int cuantos,
    VBreakpoint punto,
  ) {
    return switch (_enCascada(_alignContent, punto) ?? VAlignContent.stretch) {
      VAlignContent.start => (0, 0, 0),
      VAlignContent.center => (sobra / 2, 0, 0),
      VAlignContent.end => (sobra, 0, 0),
      VAlignContent.stretch => (0, 0, sobra / cuantos),
      VAlignContent.spaceBetween =>
        cuantos > 1 ? (0, sobra / (cuantos - 1), 0) : (0, 0, 0),
      VAlignContent.spaceAround => (sobra / cuantos / 2, sobra / cuantos, 0),
      VAlignContent.spaceEvenly => (
        sobra / (cuantos + 1),
        sobra / (cuantos + 1),
        0,
      ),
    };
  }

  /// Lo que ocupa un renglón ya repartido, con sus canalones.
  double _anchoUsado(List<_Columna> columnas) {
    var usado = gutterX * (columnas.length - 1);

    for (final columna in columnas) {
      usado += columna.desplazamiento + columna.ancho;
    }

    return usado;
  }

  /// La alineación que le toca a una columna: la suya si la declaró, y si no
  /// la de la fila.
  VAlign _alineacionDe(_Columna columna, VBreakpoint punto) =>
      columna.spec.alignSelf ?? _enCascada(_align, punto) ?? VAlign.stretch;

  /// El valor declarado en [punto] o, si ahí no hay ninguno, el último
  /// declarado por debajo.
  T? _enCascada<T>(List<T?> valores, VBreakpoint punto) {
    for (var i = punto.index; i >= 0; i--) {
      final valor = valores[i];
      if (valor != null) return valor;
    }

    return null;
  }

  VColSpec _spec(RenderBox hijo) => (hijo.parentData! as VColParentData).spec;

  RenderBox? _siguiente(RenderBox hijo) =>
      (hijo.parentData! as VColParentData).nextSibling;
}

/// Una columna mientras se reparte el ancho del renglón.
class _Columna {
  _Columna({
    required this.child,
    required this.spec,
    required this.base,
    required this.minimo,
    required this.maximo,
    required this.desplazamiento,
    required this.crece,
  });

  final RenderBox child;
  final VColSpec spec;

  /// Lo que la columna pide de salida, antes de repartir nada.
  final double base;
  final double minimo;
  final double maximo;

  /// Lo que se deja vacío a su izquierda.
  final double desplazamiento;

  /// Si se queda con parte de lo que sobre.
  final bool crece;

  double ancho = 0;
  double alto = 0;
  double ascenso = 0;

  /// Lo que la columna ocuparía sin repartir: con lo que se decide si cabe en
  /// el renglón.
  double get hipotetico => base.clamp(minimo, maximo);
}

/// Un renglón de la fila: las columnas que cupieron y lo que miden juntas.
class _Renglon {
  _Renglon(this.columnas);

  final List<_Columna> columnas;

  double alto = 0;

  /// La línea base más baja del renglón, para alinear por ella.
  double ascenso = 0;
}

/// Lo que devuelve un reparto: el tamaño de la fila.
class _Reparto {
  const _Reparto(this.size);

  final Size size;
}
