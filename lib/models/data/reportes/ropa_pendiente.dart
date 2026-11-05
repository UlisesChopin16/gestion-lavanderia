import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart'
    show compararFolios;
import 'package:gestion_lavanderia/types/unit_type.dart';

/// Medio centavo: el margen con el que la base da un saldo por cero.
const double _margen = 0.005;

/// Un renglón de ropa que falta por entregar.
@immutable
class ConceptoPendiente {
  const ConceptoPendiente({
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.prometida,
  });

  final String nombre;
  final double cantidad;
  final UnitType unidad;

  /// Para cuándo se prometió.
  final DateTime prometida;

  /// `3 Piezas Camisa`, `2.5 Kgs Ropa de color`.
  String get descripcion {
    final numero = cantidad == cantidad.roundToDouble()
        ? cantidad.toStringAsFixed(0)
        : cantidad.toStringAsFixed(1);

    return '$numero ${cantidad == 1 ? unidad.value : unidad.plural} $nombre';
  }
}

/// Cómo va una orden con su entrega, contra hoy.
enum EstadoEntrega {
  vencida(titulo: 'Vencida'),
  hoy(titulo: 'Para hoy'),
  proxima(titulo: 'Próximos días');

  const EstadoEntrega({required this.titulo});

  final String titulo;
}

/// Cuántos días lleva atrasada una orden, en grupos.
enum RetrasoEntrega {
  dosDias(titulo: '1 o 2 días'),
  semana(titulo: 'De 3 a 7 días'),
  mes(titulo: 'De 8 a 30 días'),
  masDeUnMes(titulo: 'Más de 30 días');

  const RetrasoEntrega({required this.titulo});

  final String titulo;

  /// El grupo de una orden con [dias] de retraso; desde uno.
  static RetrasoEntrega de(int dias) => switch (dias) {
    <= 2 => dosDias,
    <= 7 => semana,
    <= 30 => mes,
    _ => masDeUnMes,
  };
}

/// Una orden a la que le falta ropa por entregar.
@immutable
class OrdenConRopaPendiente {
  OrdenConRopaPendiente({
    required this.folio,
    required this.cliente,
    required this.telefono,
    required this.saldo,
    required List<ConceptoPendiente> conceptos,
  }) : conceptos = List.unmodifiable(
         conceptos.sortedBy((concepto) => concepto.prometida),
       );

  final String folio;
  final String cliente;
  final String telefono;

  /// Lo que falta por cobrar de la orden.
  final double saldo;

  /// Los que faltan, del prometido para antes al prometido para después.
  final List<ConceptoPendiente> conceptos;

  bool get pagada => saldo <= _margen;

  /// La fecha más próxima de lo que falta: si ésa ya pasó, la orden está
  /// vencida aunque el resto se haya prometido para después.
  DateTime get prometida => conceptos.first.prometida;

  /// Cuántos días van desde la fecha prometida; cero o menos si todavía no
  /// llega.
  int diasDeRetraso(DateTime hoy) => _dias(prometida, hoy);

  EstadoEntrega estadoAl(DateTime hoy) => _estadoDe(prometida, hoy);
}

/// Lo que se debe entregar en un día.
typedef EntregasDelDia = ({DateTime dia, int conceptos});

/// La ropa que falta por entregar: lo vencido, lo de hoy, lo que viene y lo
/// que ya se pagó y nadie ha recogido.
@immutable
class RopaPendiente {
  /// Las [ordenes] pueden llegar en cualquier orden: aquí se ordenan por
  /// folio.
  RopaPendiente({
    required this.hoy,
    required List<OrdenConRopaPendiente> ordenes,
  }) : ordenes = List.unmodifiable(
         ordenes.sorted((a, b) => compararFolios(a.folio, b.folio)),
       );

  /// Cuántos días se ven hacia adelante, contando hoy.
  static const diasPorVenir = 7;

  final DateTime hoy;
  final List<OrdenConRopaPendiente> ordenes;

  Iterable<ConceptoPendiente> get _conceptos =>
      ordenes.expand((orden) => orden.conceptos);

  /// Las órdenes en ese estado.
  List<OrdenConRopaPendiente> en(EstadoEntrega estado) =>
      ordenes.where((orden) => orden.estadoAl(hoy) == estado).toList();

  /// Las que ya se pagaron, ya pasó su fecha y nadie ha venido por ellas.
  List<OrdenConRopaPendiente> get pagadasSinRecoger => ordenes
      .where((o) => o.pagada && o.estadoAl(hoy) == EstadoEntrega.vencida)
      .toList();

  /// Cuántos conceptos faltan, por lo que pasa con cada uno —no con su
  /// orden—: un concepto para mañana de una orden vencida es "próximo".
  int conceptosEn(EstadoEntrega estado) =>
      _conceptos.where((c) => _estadoDe(c.prometida, hoy) == estado).length;

  /// Cuántas órdenes vencidas hay en cada grupo de retraso, en su orden.
  Map<RetrasoEntrega, int> get porRetraso {
    final vencidas = en(EstadoEntrega.vencida);

    return {
      for (final retraso in RetrasoEntrega.values)
        retraso: vencidas
            .where((o) => RetrasoEntrega.de(o.diasDeRetraso(hoy)) == retraso)
            .length,
    };
  }

  /// Cuántos conceptos se prometieron para cada uno de los próximos
  /// [diasPorVenir] días, empezando hoy. Lo vencido no está aquí: tiene su
  /// propia cifra.
  List<EntregasDelDia> get porVenir {
    final porDia = groupBy(
      _conceptos.where((c) => _dias(c.prometida, hoy) <= 0),
      (c) => DateTime(c.prometida.year, c.prometida.month, c.prometida.day),
    );

    final dias = [
      for (var i = 0; i < diasPorVenir; i++)
        DateTime(hoy.year, hoy.month, hoy.day + i),
    ];

    return [
      for (final dia in dias) (dia: dia, conceptos: porDia[dia]?.length ?? 0),
    ];
  }
}

/// Si algo prometido para [prometida] está vencido, es para hoy o todavía
/// no llega.
EstadoEntrega _estadoDe(DateTime prometida, DateTime hoy) =>
    switch (_dias(prometida, hoy)) {
      > 0 => EstadoEntrega.vencida,
      0 => EstadoEntrega.hoy,
      _ => EstadoEntrega.proxima,
    };

/// Días de calendario entre dos fechas, sin contar la hora.
int _dias(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;
