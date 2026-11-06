import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/concepto_reporte.dart';
import 'package:gestion_lavanderia/models/data/reportes/periodo_reporte.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart'
    show compararFolios;
import 'package:gestion_lavanderia/types/unit_type.dart';

/// Un renglón de ropa ya terminado: para cuándo se prometió, cuándo quedó
/// listo y, si ya pasó el cliente, cuándo se lo llevó.
@immutable
class ConceptoTerminado {
  const ConceptoTerminado({
    required this.folio,
    required this.cliente,
    required this.concepto,
    required this.cantidad,
    required this.unidad,
    required this.categoria,
    required this.prometida,
    required this.lista,
    this.entregada,
  });

  final String folio;
  final String cliente;
  final String concepto;
  final double cantidad;
  final UnitType unidad;
  final String categoria;
  final DateTime prometida;

  /// Cuándo quedó listo: es lo que dice si la lavandería cumplió.
  final DateTime lista;

  /// Cuándo se lo llevó el cliente; `null` si todavía no pasa.
  final DateTime? entregada;

  /// `2 Piezas Camisa`.
  String get descripcion =>
      describirConcepto(nombre: concepto, cantidad: cantidad, unidad: unidad);

  /// Días de diferencia entre lo prometido y lo terminado, por calendario:
  /// cero es el mismo día, negativo es antes y positivo es tarde.
  int get retraso => diasEntre(prometida, lista);

  /// A tiempo es listo el día prometido o antes: la hora no cuenta, porque
  /// lo que se promete al cliente es un día.
  bool get aTiempo => retraso <= 0;

  /// Cuántos días tardó el cliente en pasar por él desde que estuvo listo;
  /// `null` si todavía no pasa.
  int? get diasParaRecoger {
    final entregada = this.entregada;
    return entregada == null ? null : diasEntre(lista, entregada);
  }
}

/// Cuándo quedó lista la ropa contra lo prometido, en grupos.
enum MomentoEntrega {
  antes(titulo: 'Antes', corto: 'Antes'),
  elDia(titulo: 'El día prometido', corto: 'El día'),
  unDia(titulo: '1 día tarde', corto: '1 día'),
  pocosDias(titulo: '2 o 3 días tarde', corto: '2-3 días'),
  semana(titulo: 'De 4 a 7 días tarde', corto: '4-7 días'),
  masDeUnaSemana(titulo: 'Más de 7 días tarde', corto: '8+ días');

  const MomentoEntrega({required this.titulo, required this.corto});

  final String titulo;

  /// Lo que cabe bajo una columna.
  final String corto;

  bool get aTiempo => this == antes || this == elDia;

  static MomentoEntrega de(int retraso) => switch (retraso) {
    < 0 => antes,
    0 => elDia,
    1 => unDia,
    <= 3 => pocosDias,
    <= 7 => semana,
    _ => masDeUnaSemana,
  };
}

/// Cómo cumple una categoría con lo que promete.
@immutable
class CumplimientoCategoria {
  const CumplimientoCategoria({
    required this.categoria,
    required this.terminados,
    required this.aTiempo,
  });

  final String categoria;
  final int terminados;
  final int aTiempo;

  int get tarde => terminados - aTiempo;

  /// De 0 a 1.
  double get fraccion => terminados == 0 ? 0 : aTiempo / terminados;
}

/// La ropa terminada en un periodo contra lo que se prometió: cuánta quedó
/// lista a tiempo, cuál se atrasó, en qué categorías, y cuánto tardan los
/// clientes en pasar por ella.
///
/// Se mide cuándo quedó lista y no cuándo se entregó: si el cliente pasa un
/// día después, la lavandería cumplió igual.
@immutable
class EntregasATiempo {
  /// Los [terminados] pueden llegar en cualquier orden: aquí se ordenan por
  /// folio y, los de una misma orden, por fecha prometida.
  EntregasATiempo({
    required this.rango,
    required List<ConceptoTerminado> terminados,
  }) : terminados = List.unmodifiable(
         terminados.sorted((a, b) {
           final porFolio = compararFolios(a.folio, b.folio);
           return porFolio != 0 ? porFolio : a.prometida.compareTo(b.prometida);
         }),
       );

  /// Los días en que se terminó: es lo que mete un concepto en el periodo.
  final RangoReporte rango;

  final List<ConceptoTerminado> terminados;

  int get aTiempo => terminados.where((t) => t.aTiempo).length;

  /// Los que quedaron listos tarde, por folio.
  List<ConceptoTerminado> get tarde =>
      terminados.where((t) => !t.aTiempo).toList();

  /// De 0 a 1, o `null` si no se terminó nada y no hay qué medir.
  double? get fraccionATiempo =>
      terminados.isEmpty ? null : aTiempo / terminados.length;

  /// Cuántos días tarde, en promedio, los que se atrasaron; `null` si
  /// ninguno.
  double? get retrasoPromedio {
    final tarde = this.tarde;
    if (tarde.isEmpty) return null;

    return tarde.map((t) => t.retraso).sum / tarde.length;
  }

  /// El que más se atrasó; `null` si ninguno.
  ConceptoTerminado? get mayorRetraso =>
      maxBy(tarde, (ConceptoTerminado t) => t.retraso);

  /// Cuántos días tardan los clientes, en promedio, en pasar por lo que ya
  /// está listo; `null` si nadie ha pasado todavía.
  double? get recogidaPromedio {
    final dias = terminados.map((t) => t.diasParaRecoger).nonNulls;
    if (dias.isEmpty) return null;

    return dias.sum / dias.length;
  }

  /// Cuántos de los terminados siguen esperando al cliente.
  int get sinRecoger => terminados.where((t) => t.entregada == null).length;

  /// Cada categoría con lo que terminó, de la que peor cumple a la que
  /// mejor: la de arriba es la que hay que revisar.
  List<CumplimientoCategoria> get porCategoria {
    final grupos = groupBy(terminados, (t) => t.categoria);

    return [
      for (final MapEntry(key: categoria, value: terminados) in grupos.entries)
        CumplimientoCategoria(
          categoria: categoria,
          terminados: terminados.length,
          aTiempo: terminados.where((t) => t.aTiempo).length,
        ),
    ].sorted((a, b) {
      final porFraccion = a.fraccion.compareTo(b.fraccion);
      return porFraccion != 0
          ? porFraccion
          : a.categoria.compareTo(b.categoria);
    });
  }

  /// Cuántos conceptos cayeron en cada momento, siempre todos y en su orden.
  Map<MomentoEntrega, int> get porMomento {
    final grupos = groupBy(terminados, (t) => MomentoEntrega.de(t.retraso));

    return {
      for (final momento in MomentoEntrega.values)
        momento: grupos[momento]?.length ?? 0,
    };
  }
}
