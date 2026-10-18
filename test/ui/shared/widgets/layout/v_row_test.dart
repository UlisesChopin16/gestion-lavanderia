import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/layout/layout.dart';

/// La rejilla de doce columnas, medida con la regla.
///
/// Las cuentas que se comprueban son las de Vuetify: una columna de `n` mide
/// `n * (ancho + canalón) / 12 - canalón`, de modo que las de un renglón
/// suman el ancho entero contando el aire que llevan en medio.
void main() {
  const ancho = 800.0;
  const canalon = 24.0;

  /// Lo que mide una columna de [n] doceavos en una fila de [ancho].
  double doceavos(int n, {double aire = canalon}) =>
      n * (ancho + aire) / 12 - aire;

  Future<void> mostrar(
    WidgetTester tester,
    Widget fila, {
    double anchoFila = ancho,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: anchoFila, child: fila),
        ),
      ),
    );
  }

  Widget caja(String llave, {double? width, double height = 50}) =>
      SizedBox(key: Key(llave), width: width, height: height);

  Rect rect(WidgetTester tester, String llave) =>
      tester.getRect(find.byKey(Key(llave)));

  group('VRow', () {
    testWidgets('dos columnas de seis llenan el ancho con el aire en medio', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 6, child: caja('a')),
            VCol(cols: 6, child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'a').left, 0);
      expect(rect(tester, 'a').width, closeTo(doceavos(6), 0.01));
      expect(
        rect(tester, 'b').left,
        closeTo(doceavos(6) + canalon, 0.01),
      );
      expect(
        rect(tester, 'a').width + canalon + rect(tester, 'b').width,
        closeTo(ancho, 0.01),
      );
    });

    testWidgets('la columna que no cabe abre el renglón siguiente', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 5, child: caja('a')),
            VCol(cols: 5, child: caja('b')),
            VCol(cols: 5, child: caja('c')),
          ],
        ),
      );

      expect(rect(tester, 'a').top, 0);
      expect(rect(tester, 'b').top, 0);
      // El tercero baja, separado por el mismo aire que hay entre columnas.
      expect(rect(tester, 'c').top, closeTo(50 + canalon, 0.01));
      expect(rect(tester, 'c').left, 0);
    });

    testWidgets('las columnas sin tamaño se reparten lo que sobra', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 6, child: caja('a')),
            VCol(child: caja('b')),
            VCol(child: caja('c')),
          ],
        ),
      );

      final sobra = ancho - doceavos(6) - canalon * 2;

      expect(rect(tester, 'b').width, closeTo(sobra / 2, 0.01));
      expect(rect(tester, 'c').width, closeTo(sobra / 2, 0.01));
    });

    testWidgets('un hijo suelto cuenta como columna que crece', (tester) async {
      await mostrar(
        tester,
        VRow(children: [caja('a'), caja('b')]),
      );

      expect(rect(tester, 'a').width, closeTo((ancho - canalon) / 2, 0.01));
      expect(rect(tester, 'b').width, closeTo((ancho - canalon) / 2, 0.01));
    });

    testWidgets('VCol.auto mide lo que mide su contenido', (tester) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: VCol.auto, child: caja('a', width: 120)),
            VCol(child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'a').width, 120);
      expect(rect(tester, 'b').width, closeTo(ancho - 120 - canalon, 0.01));
    });

    testWidgets('el tamaño declarado vale desde su punto de quiebre', (
      tester,
    ) async {
      final fila = VRow(
        children: [
          VCol(cols: 12, sm: 6, child: caja('a')),
          VCol(cols: 12, sm: 6, child: caja('b')),
        ],
      );

      // Por debajo de sm cada columna ocupa la fila entera.
      await mostrar(tester, fila, anchoFila: 500);
      expect(rect(tester, 'a').width, 500);
      expect(rect(tester, 'b').top, closeTo(50 + canalon, 0.01));

      // Desde sm se parten la fila.
      await mostrar(tester, fila, anchoFila: 700);
      expect(rect(tester, 'a').width, closeTo(6 * 724 / 12 - canalon, 0.01));
      expect(rect(tester, 'b').top, 0);
    });

    testWidgets('offset deja columnas vacías antes', (tester) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 6, offset: 6, child: caja('a')),
          ],
        ),
      );

      expect(rect(tester, 'a').left, closeTo(6 * (ancho + canalon) / 12, 0.01));
    });

    testWidgets('order cambia el lugar sin cambiar el código', (tester) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 6, order: 1, child: caja('a')),
            VCol(cols: 6, order: -1, child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'b').left, 0);
      expect(rect(tester, 'a').left, closeTo(doceavos(6) + canalon, 0.01));
    });

    testWidgets('noGutters pega unas columnas con otras', (tester) async {
      await mostrar(
        tester,
        VRow(
          noGutters: true,
          children: [
            VCol(cols: 6, child: caja('a')),
            VCol(cols: 6, child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'a').width, closeTo(ancho / 2, 0.01));
      expect(rect(tester, 'b').left, closeTo(ancho / 2, 0.01));
    });

    testWidgets('dense deja el aire de la densidad compacta', (tester) async {
      await mostrar(
        tester,
        VRow(
          dense: true,
          children: [
            VCol(cols: 6, child: caja('a')),
            VCol(cols: 6, child: caja('b')),
          ],
        ),
      );

      expect(
        rect(tester, 'b').left - rect(tester, 'a').right,
        closeTo(VDensity.compact.gutter, 0.01),
      );
    });

    testWidgets('sin alineación las columnas se estiran a la más alta', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 6, child: caja('a', height: 20)),
            VCol(cols: 6, child: caja('b', height: 60)),
          ],
        ),
      );

      expect(rect(tester, 'a').height, 60);
      expect(rect(tester, 'b').height, 60);
    });

    testWidgets('centradas, la más baja queda a media altura', (tester) async {
      await mostrar(
        tester,
        VRow(
          align: VAlign.center,
          children: [
            VCol(cols: 6, child: caja('a', height: 20)),
            VCol(cols: 6, child: caja('b', height: 60)),
          ],
        ),
      );

      expect(rect(tester, 'a').height, 20);
      expect(rect(tester, 'a').top, 20);
      expect(rect(tester, 'b').top, 0);
    });

    testWidgets('alignSelf manda sobre la alineación de la fila', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          align: VAlign.center,
          children: [
            VCol(cols: 6, alignSelf: VAlign.end, child: caja('a', height: 20)),
            VCol(cols: 6, child: caja('b', height: 60)),
          ],
        ),
      );

      expect(rect(tester, 'a').top, 40);
    });

    testWidgets('minWidth parte el renglón antes que aplastar la columna', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(minWidth: 300, child: caja('a')),
            VCol(minWidth: 300, child: caja('b')),
            VCol(minWidth: 300, child: caja('c')),
          ],
        ),
      );

      // Tres columnas de 300 no caben en 800, así que la tercera baja y las
      // dos de arriba se reparten el ancho entero.
      expect(rect(tester, 'c').top, closeTo(50 + canalon, 0.01));
      expect(rect(tester, 'a').width, closeTo((ancho - canalon) / 2, 0.01));
      expect(rect(tester, 'c').width, closeTo(ancho, 0.01));
    });

    testWidgets('maxWidth frena a la columna aunque sobre espacio', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(maxWidth: 200, child: caja('a')),
            VCol(child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'a').width, 200);
      // Lo que la primera no se queda vuelve a repartirse: aquí, entero para
      // la segunda.
      expect(rect(tester, 'b').width, closeTo(ancho - 200 - canalon, 0.01));
    });

    testWidgets('justify reparte lo que sobra cuando nadie crece', (
      tester,
    ) async {
      await mostrar(
        tester,
        VRow(
          justify: VJustify.end,
          children: [
            VCol(cols: 3, child: caja('a')),
            VCol(cols: 3, child: caja('b')),
          ],
        ),
      );

      expect(rect(tester, 'b').right, closeTo(ancho, 0.01));
    });

    testWidgets('de derecha a izquierda empieza por el otro lado', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: ancho,
              child: VRow(
                children: [
                  VCol(cols: 6, child: caja('a')),
                  VCol(cols: 6, child: caja('b')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(rect(tester, 'a').right, closeTo(ancho, 0.01));
      expect(rect(tester, 'b').left, 0);
    });

    testWidgets('la fila mide lo que suman sus renglones', (tester) async {
      await mostrar(
        tester,
        VRow(
          children: [
            VCol(cols: 12, child: caja('a', height: 40)),
            VCol(cols: 12, child: caja('b', height: 30)),
          ],
        ),
      );

      expect(
        tester.getSize(find.byType(VRow)),
        const Size(ancho, 40 + canalon + 30),
      );
    });

    testWidgets('sin ancho conocido cada columna se queda con lo suyo', (
      tester,
    ) async {
      // Dentro de una fila horizontal desplazable no hay ancho del que sacar
      // doceavos: antes esto reventaba con una restricción infinita.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: VRow(
                children: [
                  VCol(cols: 6, child: caja('a', width: 100)),
                  VCol(cols: 6, child: caja('b', width: 150)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(rect(tester, 'a').width, 100);
      expect(rect(tester, 'b').width, 150);
      expect(rect(tester, 'b').left, closeTo(100 + canalon, 0.01));
    });
  });
}
