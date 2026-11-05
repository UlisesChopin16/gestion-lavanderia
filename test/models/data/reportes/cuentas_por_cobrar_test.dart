import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/cuentas_por_cobrar.dart';

/// Las cuentas por cobrar sin base: cuánto lleva cada orden debiendo, en
/// qué grupo cae y quién debe más.
void main() {
  final hoy = DateTime(2026, 11, 5);

  SaldoPendiente saldo(
    String folio, {
    required int hace,
    double saldo = 100,
    int clienteId = 1,
    String cliente = 'Ana López',
  }) => SaldoPendiente(
    folio: folio,
    clienteId: clienteId,
    cliente: cliente,
    telefono: '555000000$clienteId',
    // La hora no cuenta: una orden de anoche ya lleva un día.
    recibida: DateTime(hoy.year, hoy.month, hoy.day - hace, 21, 30),
    total: 300,
    saldo: saldo,
  );

  test('los grupos cortan en una semana y en un mes', () {
    expect(AntiguedadSaldo.de(0), AntiguedadSaldo.semana);
    expect(AntiguedadSaldo.de(6), AntiguedadSaldo.semana);
    expect(AntiguedadSaldo.de(7), AntiguedadSaldo.mes);
    expect(AntiguedadSaldo.de(30), AntiguedadSaldo.mes);
    expect(AntiguedadSaldo.de(31), AntiguedadSaldo.masDeUnMes);
  });

  test('los días se cuentan por calendario, no por horas', () {
    expect(saldo('A', hace: 1).diasHasta(hoy), 1);
    expect(saldo('A', hace: 0).diasHasta(hoy), 0);
  });

  group('las cuentas', () {
    final cuentas = CuentasPorCobrar(
      hoy: hoy,
      saldos: [
        saldo('2611-0003', hace: 2, saldo: 50, clienteId: 2, cliente: 'Luis'),
        saldo('2609-0010', hace: 45, saldo: 200),
        saldo('2610-0020', hace: 10, saldo: 120),
        saldo('2611-0001', hace: 4, saldo: 30, clienteId: 3, cliente: 'Rosa'),
      ],
    );

    test('van por folio', () {
      expect(cuentas.saldos.map((s) => s.folio), [
        '2609-0010',
        '2610-0020',
        '2611-0001',
        '2611-0003',
      ]);
    });

    test('la más antigua sale de la fecha, no del folio', () {
      final desordenadas = CuentasPorCobrar(
        hoy: hoy,
        saldos: [saldo('2611-0001', hace: 3), saldo('2611-0002', hace: 40)],
      );

      expect(desordenadas.masAntigua?.folio, '2611-0002');
      expect(CuentasPorCobrar(hoy: hoy, saldos: const []).masAntigua, isNull);
    });

    test('suman lo que se debe y cuentan a los clientes una vez', () {
      expect(cuentas.total, 400);
      expect(cuentas.clientes, 3);
    });

    test('cada grupo dice cuánto y en cuántas órdenes', () {
      expect(cuentas.porAntiguedad, {
        AntiguedadSaldo.semana: (saldo: 80.0, ordenes: 2),
        AntiguedadSaldo.mes: (saldo: 120.0, ordenes: 1),
        AntiguedadSaldo.masDeUnMes: (saldo: 200.0, ordenes: 1),
      });
      expect(cuentas.de(AntiguedadSaldo.semana).map((s) => s.folio), [
        '2611-0001',
        '2611-0003',
      ]);
      expect(cuentas.de(null), hasLength(4));
    });

    test('los que más deben juntan sus órdenes', () {
      final deudas = cuentas.clientesQueMasDeben(cuantos: 2);

      expect(deudas.map((d) => (d.cliente, d.saldo, d.ordenes)), [
        ('Ana López', 320.0, 2),
        ('Luis', 50.0, 1),
      ]);
    });
  });
}
