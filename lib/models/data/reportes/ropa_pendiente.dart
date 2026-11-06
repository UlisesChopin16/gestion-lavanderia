import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/concepto_reporte.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart'
    show compararFolios;
import 'package:gestion_lavanderia/types/unit_type.dart';

/// Medio centavo: el margen con el que la base da un saldo por cero.
const double _margen = 0.005;

/// Un renglón de ropa que falta por entregar: por terminar, o ya listo y
/// esperando al cliente.
@immutable
class ConceptoPendiente {
  const ConceptoPendiente({
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.prometida,
    this.lista,
  });

  final String nombre;
  final double cantidad;
  final UnitType unidad;

  /// Para cuándo se prometió.
  final DateTime prometida;

  /// Cuándo quedó listo; `null` mientras se trabaja en él.
  final DateTime? lista;

  bool get estaLista => lista != null;

  /// `3 Piezas Camisa`, `2.5 Kgs Ropa de color`.
  String get descripcion =>
      describirConcepto(nombre: nombre, cantidad: cantidad, unidad: unidad);
}

/// En qué va la ropa pendiente, contra hoy.
///
/// Lo listo va aparte de las fechas: si ya está terminado, que el cliente no
/// haya pasado por él no es un retraso de la lavandería.
enum EstadoEntrega {
  atrasada(titulo: 'Atrasada'),
  hoy(titulo: 'Para hoy'),
  proxima(titulo: 'Próximos días'),
  lista(titulo: 'Lista para recoger');

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

  /// Lo que falta terminar.
  List<ConceptoPendiente> get porTerminar =>
      conceptos.where((c) => !c.estaLista).toList();

  /// Lo que ya está listo y espera al cliente.
  List<ConceptoPendiente> get listos =>
      conceptos.where((c) => c.estaLista).toList();

  /// La fecha más próxima de lo que falta terminar: si ésa ya pasó, la orden
  /// está atrasada aunque el resto se haya prometido para después. En `null`
  /// si todo está listo.
  DateTime? get prometida => porTerminar.firstOrNull?.prometida;

  /// Desde cuándo espera al cliente lo primero que quedó listo; `null` si
  /// nada está listo.
  DateTime? get listaDesde => listos.map((c) => c.lista!).minOrNull;

  /// Cuántos días van desde la fecha prometida de lo que falta terminar;
  /// cero o menos si todavía no llega, y cero si todo está listo.
  int diasDeRetraso(DateTime hoy) {
    final prometida = this.prometida;
    return prometida == null ? 0 : diasEntre(prometida, hoy);
  }

  /// Cuántos días lleva esperando al cliente lo que está listo.
  int diasEsperando(DateTime hoy) {
    final desde = listaDesde;
    return desde == null ? 0 : diasEntre(desde, hoy);
  }

  /// Lo atrasado manda sobre lo listo: una orden con algo listo y algo
  /// atrasado está atrasada. Sólo si todo está listo, está lista.
  EstadoEntrega estadoAl(DateTime hoy) {
    final prometida = this.prometida;
    return prometida == null ? EstadoEntrega.lista : _estadoDe(prometida, hoy);
  }
}

/// Lo que hay que tener listo en un día.
typedef EntregasDelDia = ({DateTime dia, int conceptos});

/// La ropa que falta por entregar: lo atrasado, lo de hoy, lo que viene y lo
/// que ya está listo y nadie ha recogido.
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

  /// Las que tienen algo listo esperando al cliente, aunque les falte
  /// terminar lo demás: a esos clientes hay que avisarles.
  List<OrdenConRopaPendiente> get conAlgoListo =>
      ordenes.where((orden) => orden.listos.isNotEmpty).toList();

  /// Cuántos conceptos hay en ese estado, por lo que pasa con cada uno —no
  /// con su orden—: un concepto para mañana de una orden atrasada es
  /// "próximo", y uno listo es "listo" aunque su orden esté atrasada.
  int conceptosEn(EstadoEntrega estado) =>
      _conceptos.where((c) => _estadoDelConcepto(c, hoy) == estado).length;

  /// Cuántas órdenes atrasadas hay en cada grupo de retraso, en su orden.
  Map<RetrasoEntrega, int> get porRetraso {
    final atrasadas = en(EstadoEntrega.atrasada);

    return {
      for (final retraso in RetrasoEntrega.values)
        retraso: atrasadas
            .where((o) => RetrasoEntrega.de(o.diasDeRetraso(hoy)) == retraso)
            .length,
    };
  }

  /// Cuántos conceptos por terminar se prometieron para cada uno de los
  /// próximos [diasPorVenir] días, empezando hoy. Lo atrasado y lo listo no
  /// están aquí: tienen su propia cifra.
  List<EntregasDelDia> get porVenir {
    final porDia = groupBy(
      _conceptos.where((c) => !c.estaLista && diasEntre(c.prometida, hoy) <= 0),
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

/// Lo listo es listo; lo demás, según su fecha.
EstadoEntrega _estadoDelConcepto(ConceptoPendiente concepto, DateTime hoy) =>
    concepto.estaLista
    ? EstadoEntrega.lista
    : _estadoDe(concepto.prometida, hoy);

/// Si algo por terminar prometido para [prometida] está atrasado, es para
/// hoy o todavía no llega.
EstadoEntrega _estadoDe(DateTime prometida, DateTime hoy) =>
    switch (diasEntre(prometida, hoy)) {
      > 0 => EstadoEntrega.atrasada,
      0 => EstadoEntrega.hoy,
      _ => EstadoEntrega.proxima,
    };
