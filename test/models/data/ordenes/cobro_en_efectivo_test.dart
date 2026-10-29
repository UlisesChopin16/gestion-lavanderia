import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Comprueba las cuentas de un cobro en efectivo, que comparten el adelanto
/// del alta y el cobro del detalle.
void main() {
  CobroEnEfectivo cobro({
    MetodoPagoType metodoPago = MetodoPagoType.efectivo,
    double abono = 300,
    double recibido = 0,
  }) {
    return CobroEnEfectivo(
      metodoPago: metodoPago,
      abono: abono,
      recibido: recibido,
    );
  }

  test('saca el cambio de lo que entrega el cliente', () {
    final efectivo = cobro(recibido: 500);

    expect(efectivo.cambio, 200);
    expect(efectivo.insuficiente, isFalse);
    expect(efectivo.aGuardar, 500);
  });

  test('sin nada escrito da por pagado justo y lo guarda así', () {
    final efectivo = cobro();

    expect(efectivo.insuficiente, isFalse);
    expect(efectivo.aGuardar, 300);
  });

  test('un billete que no alcanza se avisa', () {
    expect(cobro(recibido: 200).insuficiente, isTrue);
  });

  test('pagar exacto no es quedarse corto', () {
    expect(cobro(recibido: 300).insuficiente, isFalse);
  });

  test('sin abono no hay efectivo que contar', () {
    final efectivo = cobro(abono: 0, recibido: 500);

    expect(efectivo.aplica, isFalse);
    expect(efectivo.insuficiente, isFalse);
    expect(efectivo.aGuardar, isNull);
  });

  test('con tarjeta no hay efectivo que contar', () {
    final efectivo = cobro(metodoPago: MetodoPagoType.tarjeta, recibido: 100);

    expect(efectivo.aplica, isFalse);
    expect(efectivo.insuficiente, isFalse);
    expect(efectivo.aGuardar, isNull);
  });
}
