import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/entregas_a_tiempo.dart';
import 'package:gestion_lavanderia/models/data/reportes/periodo_reporte.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';

/// Las entregas a tiempo sin base: qué cuenta como a tiempo —cuándo quedó
/// lista, no cuándo vino el cliente—, cuánto se atrasó cada una y cómo
/// cumple cada categoría.
void main() {
  final prometida = DateTime(2026, 11, 3, 18);

  ConceptoTerminado terminado(
    String folio, {
    required int retraso,
    String categoria = 'Planchado',
    int hora = 10,
    int? recogidaDespues,
  }) {
    final lista = DateTime(2026, 11, 3 + retraso, hora);

    return ConceptoTerminado(
      folio: folio,
      cliente: 'Ana López',
      concepto: 'Camisa',
      cantidad: 2,
      unidad: UnitType.pieza,
      categoria: categoria,
      prometida: prometida,
      lista: lista,
      entregada: recogidaDespues == null
          ? null
          : DateTime(lista.year, lista.month, lista.day + recogidaDespues, 17),
    );
  }

  test('a tiempo es lista el día prometido o antes, sin importar la hora', () {
    // Prometida a las 18:00 y lista a las 21:00 del mismo día.
    expect(terminado('A', retraso: 0, hora: 21).aTiempo, isTrue);
    expect(terminado('A', retraso: -1).aTiempo, isTrue);
    expect(terminado('A', retraso: 1, hora: 8).aTiempo, isFalse);
    expect(terminado('A', retraso: 3).retraso, 3);
  });

  test('si el cliente pasa días después, sigue a tiempo', () {
    final tarde = terminado('A', retraso: 0, recogidaDespues: 4);

    expect(tarde.aTiempo, isTrue);
    expect(tarde.diasParaRecoger, 4);
    expect(terminado('A', retraso: 0).diasParaRecoger, isNull);
  });

  test('cada retraso cae en su momento', () {
    expect(MomentoEntrega.de(-2), MomentoEntrega.antes);
    expect(MomentoEntrega.de(0), MomentoEntrega.elDia);
    expect(MomentoEntrega.de(1), MomentoEntrega.unDia);
    expect(MomentoEntrega.de(3), MomentoEntrega.pocosDias);
    expect(MomentoEntrega.de(4), MomentoEntrega.semana);
    expect(MomentoEntrega.de(7), MomentoEntrega.semana);
    expect(MomentoEntrega.de(8), MomentoEntrega.masDeUnaSemana);
  });

  group('lo terminado en el periodo', () {
    final entregas = EntregasATiempo(
      rango: RangoReporte(DateTime(2026, 10, 5), DateTime(2026, 11, 5)),
      terminados: [
        terminado('2611-0004', retraso: 5, categoria: 'Edredones'),
        terminado('2611-0001', retraso: 0, recogidaDespues: 1),
        terminado('2611-0002', retraso: -1, recogidaDespues: 3),
        terminado('2611-0003', retraso: 1, recogidaDespues: 0),
        terminado('2611-0005', retraso: 0, categoria: 'Edredones'),
      ],
    );

    test('va por folio', () {
      expect(entregas.terminados.map((t) => t.folio), [
        '2611-0001',
        '2611-0002',
        '2611-0003',
        '2611-0004',
        '2611-0005',
      ]);
    });

    test('cuenta lo que quedó listo a tiempo y lo que se atrasó', () {
      expect(entregas.aTiempo, 3);
      expect(entregas.fraccionATiempo, 0.6);
      expect(entregas.tarde.map((t) => t.folio), ['2611-0003', '2611-0004']);
      expect(entregas.retrasoPromedio, 3);
      expect(entregas.mayorRetraso?.folio, '2611-0004');
    });

    test('cuánto tardan en recoger, sólo con lo que ya se llevaron', () {
      expect(entregas.recogidaPromedio, closeTo(4 / 3, 1e-9));
      expect(entregas.sinRecoger, 2);
    });

    test('las categorías van de la que peor cumple a la que mejor', () {
      expect(
        entregas.porCategoria.map(
          (c) => (c.categoria, c.aTiempo, c.terminados),
        ),
        [('Edredones', 1, 2), ('Planchado', 2, 3)],
      );
    });

    test('cada momento, siempre todos y en su orden', () {
      expect(entregas.porMomento, {
        MomentoEntrega.antes: 1,
        MomentoEntrega.elDia: 2,
        MomentoEntrega.unDia: 1,
        MomentoEntrega.pocosDias: 0,
        MomentoEntrega.semana: 1,
        MomentoEntrega.masDeUnaSemana: 0,
      });
    });
  });

  test('sin nada terminado no hay porcentaje ni retrasos', () {
    final vacio = EntregasATiempo(
      rango: RangoReporte(DateTime(2026, 11, 5), DateTime(2026, 11, 5)),
      terminados: const [],
    );

    expect(vacio.fraccionATiempo, isNull);
    expect(vacio.retrasoPromedio, isNull);
    expect(vacio.mayorRetraso, isNull);
    expect(vacio.recogidaPromedio, isNull);
    expect(vacio.porCategoria, isEmpty);
  });
}
