import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Crédito ya no se ofrece, pero los pagos que lo traen se siguen leyendo.
void main() {
  test('crédito ya no se ofrece al cobrar ni al filtrar', () {
    expect(
      MetodoPagoType.seleccionables,
      isNot(contains(MetodoPagoType.credito)),
    );
    expect(MetodoPagoType.seleccionables, [
      MetodoPagoType.efectivo,
      MetodoPagoType.tarjeta,
      MetodoPagoType.transferencia,
      MetodoPagoType.otro,
    ]);
  });

  test('un pago viejo con crédito se sigue leyendo como crédito', () {
    expect(MetodoPagoType.fromString('Crédito'), MetodoPagoType.credito);
  });
}
