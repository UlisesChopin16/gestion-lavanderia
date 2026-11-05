import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/views/reportes/corte/widgets/barras_metodo.dart';

/// Las barras por método de pago se dibujan, y cada una mide lo que le toca
/// contra la mayor.
void main() {
  testWidgets('la mayor llena la pista y las demás, su parte', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: BarrasMetodo(
              porMetodo: {
                MetodoPagoType.tarjeta: 100,
                MetodoPagoType.efectivo: 400,
              },
              total: 500,
            ),
          ),
        ),
      ),
    );

    final barras = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );
    // De la mayor a la menor: efectivo y luego tarjeta.
    final efectivo = tester.getSize(barras.at(0));
    final tarjeta = tester.getSize(barras.at(1));

    expect(efectivo.height, greaterThan(0));
    expect(efectivo.width, 400);
    expect(tarjeta.width, 100);
    expect(find.text('80 %'), findsOneWidget);
    expect(find.text('20 %'), findsOneWidget);
  });
}
