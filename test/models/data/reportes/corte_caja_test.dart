import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';

/// Las cuentas del corte de caja: lo cobrado, el efectivo que debe haber y
/// el orden del detalle.
void main() {
  final dia = DateTime(2026, 11, 4);

  CobroCorte cobro(
    String folio,
    int hora,
    MetodoPagoType metodo,
    double monto, {
    double? recibido,
  }) => CobroCorte(
    folio: folio,
    cliente: 'Ana López',
    fecha: DateTime(2026, 11, 4, hora),
    metodo: metodo,
    monto: monto,
    recibido: recibido,
  );

  final corte = CorteCaja(
    dia: dia,
    generado: dia,
    cobros: [
      cobro('2611-0003', 9, MetodoPagoType.tarjeta, 200),
      // Pagó 150 con un billete de 500.
      cobro('2611-0001', 12, MetodoPagoType.efectivo, 150, recibido: 500),
      // Sin "con cuánto pagó": se toma como pagado justo.
      cobro('2611-0001', 10, MetodoPagoType.efectivo, 100),
      cobro('2610-0040', 11, MetodoPagoType.transferencia, 80),
    ],
  );

  test('el total es todo lo cobrado, de cualquier método', () {
    expect(corte.total, 530);
    expect(corte.ordenes, 3);
  });

  test('en caja debe haber lo cobrado en efectivo, no lo entregado', () {
    expect(corte.efectivoRecibido, 600);
    expect(corte.cambioEntregado, 350);
    expect(corte.efectivoCobrado, 250);
  });

  test('cada cobro en efectivo dice con cuánto pagó y su cambio', () {
    final billete = corte.cobros.firstWhere((c) => c.recibido == 500);
    expect(billete.entregado, 500);
    expect(billete.cambio, 350);

    final justo = corte.cobros.firstWhere(
      (c) => c.enEfectivo && c.recibido == null,
    );
    expect(justo.entregado, 100);
    expect(justo.cambio, 0);

    final tarjeta = corte.cobros.firstWhere((c) => !c.enEfectivo);
    expect(tarjeta.entregado, isNull);
    expect(tarjeta.cambio, isNull);
  });

  test('lo cobrado por método, en el orden de la aplicación', () {
    expect(corte.porMetodo, {
      MetodoPagoType.efectivo: 250,
      MetodoPagoType.tarjeta: 200,
      MetodoPagoType.transferencia: 80,
    });
  });

  test('el detalle va por folio y, en una misma orden, por hora', () {
    expect(
      [for (final c in corte.cobros) (c.folio, c.fecha.hour)],
      [
        ('2610-0040', 11),
        ('2611-0001', 10),
        ('2611-0001', 12),
        ('2611-0003', 9),
      ],
    );
  });

  test('un día sin cobros da todo en cero', () {
    final vacio = CorteCaja(dia: dia, generado: dia, cobros: const []);

    expect(vacio.total, 0);
    expect(vacio.efectivoCobrado, 0);
    expect(vacio.porMetodo, isEmpty);
  });

  test('lo cobrado por hora junta los cobros de la misma hora', () {
    expect(corte.porHora, {9: 200, 10: 100, 11: 80, 12: 150});
  });

  group('contra el día anterior', () {
    EstadisticasCorte conAyer(double ayer) => EstadisticasCorte(
      corte: corte,
      semana: [
        (dia: DateTime(2026, 11, 3), total: ayer),
        (dia: dia, total: corte.total),
      ],
    );

    test('dice cuánto cambió, como fracción', () {
      expect(conAyer(265).cambioContraAyer, 1);
      expect(conAyer(1060).cambioContraAyer, -0.5);
    });

    test('sin cobros el día anterior, no hay contra qué comparar', () {
      expect(conAyer(0).cambioContraAyer, isNull);
    });
  });
}
