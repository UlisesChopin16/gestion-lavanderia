import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/search_filter.dart';

/// El buscador de los listados.
///
/// Lo que se escribe no viaja en cada tecla, y lo que viene de fuera —un
/// filtro guardado, un "limpiar filtros"— manda sobre lo que hay escrito.
void main() {
  Future<void> mostrar(
    WidgetTester tester, {
    required String value,
    ValueChanged<String>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilter(
            label: 'Buscar concepto',
            value: value,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  String texto(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('espera a que se deje de escribir antes de avisar', (
    tester,
  ) async {
    final buscado = <String>[];

    await mostrar(tester, value: '', onChanged: buscado.add);

    await tester.enterText(find.byType(TextField), 'sá');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'sába');
    await tester.pump(const Duration(milliseconds: 100));

    // Todavía no: la espera se reinicia con cada tecla.
    expect(buscado, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    expect(buscado, ['sába']);
  });

  testWidgets('arranca con el texto de un filtro ya guardado', (tester) async {
    await mostrar(tester, value: 'sábana');

    expect(find.text('sábana'), findsOneWidget);
  });

  testWidgets('limpiar los filtros vacía el campo', (tester) async {
    await mostrar(tester, value: 'sábana');

    // Lo que hace el listado al limpiar: repone sus filtros y el texto llega
    // vacío desde fuera.
    await mostrar(tester, value: '');

    expect(texto(tester), isEmpty);
  });

  testWidgets('un cambio de fuera gana a lo que hubiera escrito', (
    tester,
  ) async {
    await mostrar(tester, value: '');

    await tester.enterText(find.byType(TextField), 'camis');
    await mostrar(tester, value: 'sábana');

    expect(texto(tester), 'sábana');
  });

  testWidgets('reconstruir el listado no borra lo que se está escribiendo', (
    tester,
  ) async {
    final buscado = <String>[];

    await mostrar(tester, value: '', onChanged: buscado.add);

    await tester.enterText(find.byType(TextField), 'camis');
    // El listado se vuelve a dibujar por cualquier otra cosa —otra página,
    // otro filtro— mientras la espera corre: el texto a medio escribir se
    // queda.
    await mostrar(tester, value: '', onChanged: buscado.add);

    expect(texto(tester), 'camis');

    await tester.pump(const Duration(milliseconds: 300));
    expect(buscado, ['camis']);

    // Y el eco de lo que uno acaba de escribir tampoco lo mueve.
    await mostrar(tester, value: 'camis', onChanged: buscado.add);
    expect(texto(tester), 'camis');
  });
}
