import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/estatus_filter.dart';

/// El filtro no ofrece "todos": ver todo es no filtrar, y eso se dice
/// quitando la selección.
void main() {
  Future<void> mostrar(
    WidgetTester tester, {
    required EstatusType? estatus,
    required ValueChanged<EstatusType?> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EstatusFilter(estatus: estatus, onChanged: onChanged),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sólo ofrece activo e inactivo', (tester) async {
    await mostrar(tester, estatus: EstatusType.activo, onChanged: (_) {});

    await tester.tap(find.byType(DropdownMenu<EstatusType>));
    await tester.pumpAndSettle();

    // El desplegable dibuja sus opciones dos veces —una para medirlas—, así
    // que lo que importa es que estén y que "Todos" no esté.
    expect(find.text('Inactivo'), findsWidgets);
    expect(find.text('Activo'), findsWidgets);
    expect(find.text('Todos'), findsNothing);
  });

  testWidgets('quitar la selección avisa que ya no se filtra', (tester) async {
    final elegido = <EstatusType?>[];

    await mostrar(
      tester,
      estatus: EstatusType.inactivo,
      onChanged: elegido.add,
    );

    await tester.tap(find.byTooltip('Quitar').first);
    await tester.pumpAndSettle();

    expect(elegido, [null]);
  });

  testWidgets('sin estatus elegido no hay nada que quitar', (tester) async {
    await mostrar(tester, estatus: null, onChanged: (_) {});

    expect(find.byTooltip('Quitar'), findsNothing);
  });
}
