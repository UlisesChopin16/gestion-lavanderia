import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/ropa_pendiente.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';

/// La ropa pendiente sin base: qué está atrasado, qué es para hoy y qué ya
/// está listo y nadie ha recogido.
void main() {
  final hoy = DateTime(2026, 11, 5);

  /// Prometido para dentro de [dias] días; listo hace [listaHace] días.
  ConceptoPendiente concepto(int dias, {double cantidad = 1, int? listaHace}) =>
      ConceptoPendiente(
        nombre: 'Camisa',
        cantidad: cantidad,
        unidad: UnitType.pieza,
        // A cualquier hora de ese día.
        prometida: DateTime(hoy.year, hoy.month, hoy.day + dias, 18),
        lista: listaHace == null
            ? null
            : DateTime(hoy.year, hoy.month, hoy.day - listaHace, 12),
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

  test('una orden vale por lo más próximo que le falta terminar', () {
    // Una camisa atrasada desde ayer y otra para dentro de tres días.
    final mezcla = orden('A', [concepto(3), concepto(-1)]);

    expect(mezcla.prometida?.day, 4);
    expect(mezcla.diasDeRetraso(hoy), 1);
    expect(mezcla.estadoAl(hoy), EstadoEntrega.atrasada);
    expect(orden('B', [concepto(0)]).estadoAl(hoy), EstadoEntrega.hoy);
    expect(orden('C', [concepto(2)]).estadoAl(hoy), EstadoEntrega.proxima);
  });

  test('lo listo no es un retraso aunque ya pasó la fecha', () {
    // Prometida hace cinco días, lista desde hace cuatro: el cliente no ha
    // pasado, pero la lavandería cumplió.
    final lista = orden('A', [concepto(-5, listaHace: 4)]);

    expect(lista.estadoAl(hoy), EstadoEntrega.lista);
    expect(lista.prometida, isNull);
    expect(lista.diasDeRetraso(hoy), 0);
    expect(lista.diasEsperando(hoy), 4);
  });

  test('lo atrasado manda sobre lo listo en la misma orden', () {
    final mezcla = orden('A', [concepto(-5, listaHace: 4), concepto(-2)]);

    expect(mezcla.estadoAl(hoy), EstadoEntrega.atrasada);
    expect(mezcla.diasDeRetraso(hoy), 2);
    expect(mezcla.listos, hasLength(1));
    expect(mezcla.porTerminar, hasLength(1));
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
        orden('2611-0001', [concepto(-2, listaHace: 1)]),
        orden('2610-0009', [concepto(-40)], saldo: 30),
        orden('2611-0003', [concepto(0), concepto(6)]),
        orden('2611-0002', [concepto(-5), concepto(2, listaHace: 0)]),
        orden('2611-0005', [concepto(-1, listaHace: 2)], saldo: 50),
      ],
    );

    test('va por folio', () {
      expect(ropa.ordenes.map((o) => o.folio), [
        '2610-0009',
        '2611-0001',
        '2611-0002',
        '2611-0003',
        '2611-0004',
        '2611-0005',
      ]);
    });

    test('separa lo atrasado, lo de hoy, lo que viene y lo listo', () {
      expect(ropa.en(EstadoEntrega.atrasada).map((o) => o.folio), [
        '2610-0009',
        '2611-0002',
      ]);
      expect(ropa.en(EstadoEntrega.hoy).map((o) => o.folio), ['2611-0003']);
      expect(ropa.en(EstadoEntrega.proxima).map((o) => o.folio), ['2611-0004']);
      expect(ropa.en(EstadoEntrega.lista).map((o) => o.folio), [
        '2611-0001',
        '2611-0005',
      ]);
    });

    test('cuenta los conceptos por lo que pasa con cada uno', () {
      expect(ropa.conceptosEn(EstadoEntrega.atrasada), 2);
      expect(ropa.conceptosEn(EstadoEntrega.hoy), 1);
      expect(ropa.conceptosEn(EstadoEntrega.proxima), 3);
      expect(ropa.conceptosEn(EstadoEntrega.lista), 3);
    });

    test('con algo listo son todas las que tienen algo esperando', () {
      // La 2611-0002 está atrasada, pero tiene algo listo: también se avisa.
      expect(ropa.conAlgoListo.map((o) => o.folio), [
        '2611-0001',
        '2611-0002',
        '2611-0005',
      ]);
    });

    test('el retraso se agrupa, sólo con lo que falta terminar', () {
      expect(ropa.porRetraso, {
        RetrasoEntrega.dosDias: 0,
        RetrasoEntrega.semana: 1,
        RetrasoEntrega.mes: 0,
        RetrasoEntrega.masDeUnMes: 1,
      });
    });

    test('lo que viene, día por día desde hoy y sin lo listo', () {
      expect(ropa.porVenir.map((d) => (d.dia.day, d.conceptos)), [
        (5, 1),
        (6, 2),
        (7, 0),
        (8, 0),
        (9, 0),
        (10, 0),
        (11, 1),
      ]);
    });
  });
}
