import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/ropa_pendiente.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';

/// La ropa pendiente sin base: qué está vencido, qué es para hoy y qué ya se
/// pagó y nadie ha recogido.
void main() {
  final hoy = DateTime(2026, 11, 5);

  ConceptoPendiente concepto(int dias, {double cantidad = 1}) =>
      ConceptoPendiente(
        nombre: 'Camisa',
        cantidad: cantidad,
        unidad: UnitType.pieza,
        // A cualquier hora de ese día.
        prometida: DateTime(hoy.year, hoy.month, hoy.day + dias, 18),
      );

  OrdenConRopaPendiente orden(
    String folio,
    List<ConceptoPendiente> conceptos, {
    double saldo = 0,
  }) => OrdenConRopaPendiente(
    folio: folio,
    cliente: 'Ana López',
    telefono: '5551234567',
    saldo: saldo,
    conceptos: conceptos,
  );

  test('una orden vale por lo más próximo que le falta', () {
    // Una camisa vencida ayer y otra para dentro de tres días: está vencida.
    final mezcla = orden('A', [concepto(3), concepto(-1)]);

    expect(mezcla.prometida.day, 4);
    expect(mezcla.diasDeRetraso(hoy), 1);
    expect(mezcla.estadoAl(hoy), EstadoEntrega.vencida);
    expect(orden('B', [concepto(0)]).estadoAl(hoy), EstadoEntrega.hoy);
    expect(orden('C', [concepto(2)]).estadoAl(hoy), EstadoEntrega.proxima);
  });

  test('cada concepto se dice con su cantidad y unidad', () {
    expect(concepto(0, cantidad: 3).descripcion, '3 Piezas Camisa');
    expect(concepto(0).descripcion, '1 Pieza Camisa');
    expect(
      ConceptoPendiente(
        nombre: 'Ropa de color',
        cantidad: 2.5,
        unidad: UnitType.kilo,
        prometida: hoy,
      ).descripcion,
      '2.5 Kgs Ropa de color',
    );
  });

  group('la ropa pendiente', () {
    final ropa = RopaPendiente(
      hoy: hoy,
      ordenes: [
        orden('2611-0004', [concepto(1), concepto(1)], saldo: 80),
        orden('2611-0001', [concepto(-2)]),
        orden('2610-0009', [concepto(-40)], saldo: 30),
        orden('2611-0003', [concepto(0), concepto(6)]),
        orden('2611-0002', [concepto(-5), concepto(2)]),
      ],
    );

    test('va por folio', () {
      expect(ropa.ordenes.map((o) => o.folio), [
        '2610-0009',
        '2611-0001',
        '2611-0002',
        '2611-0003',
        '2611-0004',
      ]);
    });

    test('separa las órdenes vencidas, las de hoy y las que vienen', () {
      expect(ropa.en(EstadoEntrega.vencida).map((o) => o.folio), [
        '2610-0009',
        '2611-0001',
        '2611-0002',
      ]);
      expect(ropa.en(EstadoEntrega.hoy).map((o) => o.folio), ['2611-0003']);
      expect(ropa.en(EstadoEntrega.proxima).map((o) => o.folio), ['2611-0004']);
    });

    test('cuenta los conceptos por su propia fecha, no por la de su orden', () {
      expect(ropa.conceptosEn(EstadoEntrega.vencida), 3);
      expect(ropa.conceptosEn(EstadoEntrega.hoy), 1);
      expect(ropa.conceptosEn(EstadoEntrega.proxima), 4);
    });

    test('pagadas sin recoger son las pagadas con la fecha vencida', () {
      expect(ropa.pagadasSinRecoger.map((o) => o.folio), [
        '2611-0001',
        '2611-0002',
      ]);
    });

    test('el retraso se agrupa', () {
      expect(ropa.porRetraso, {
        RetrasoEntrega.dosDias: 1,
        RetrasoEntrega.semana: 1,
        RetrasoEntrega.mes: 0,
        RetrasoEntrega.masDeUnMes: 1,
      });
    });

    test('lo que viene, día por día desde hoy y sin lo vencido', () {
      expect(ropa.porVenir.map((d) => (d.dia.day, d.conceptos)), [
        (5, 1),
        (6, 2),
        (7, 1),
        (8, 0),
        (9, 0),
        (10, 0),
        (11, 1),
      ]);
    });
  });
}
