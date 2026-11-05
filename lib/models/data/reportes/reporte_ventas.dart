import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/periodo_reporte.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

export 'package:gestion_lavanderia/models/data/reportes/periodo_reporte.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Medio centavo: el margen con el que la base da una orden por saldada. Los
/// importes son `double`, y un cero puede quedar en 0.0000001.
const double _margen = 0.005;

/// Cómo va el pago de una orden, dicho para el reporte.
enum EstadoPagoVenta {
  pagado(titulo: 'Pagado'),
  parcial(titulo: 'Parcial'),
  pendiente(titulo: 'Pendiente'),
  cancelado(titulo: 'Cancelado');

  const EstadoPagoVenta({required this.titulo});

  final String titulo;
}

/// Un cobro en el detalle de pagos: un renglón por cada vez que entró
/// dinero.
@immutable
class PagoReporte {
  const PagoReporte({
    required this.folio,
    required this.fecha,
    required this.metodo,
    required this.monto,
  });

  /// El de la orden a la que se abonó.
  final String folio;

  final DateTime fecha;
  final MetodoPagoType metodo;
  final double monto;
}

/// Una orden en el reporte de ventas: un renglón de la tabla.
///
/// Lo pagado sale de sus [pagos], y no del saldo de la orden: así lo cobrado,
/// lo cobrado por método y el detalle de pagos salen de los mismos números y
/// siempre cuadran.
@immutable
class VentaReporte {
  const VentaReporte({
    required this.folio,
    required this.fecha,
    required this.total,
    this.cancelada = false,
    this.pagos = const [],
  });

  final String folio;

  /// Cuándo se recibió la orden: es lo que la mete en el periodo.
  final DateTime fecha;

  final double total;
  final bool cancelada;

  /// Lo que se le ha cobrado, del más antiguo al más reciente. Entran todos,
  /// aunque alguno llegara después del periodo.
  final List<PagoReporte> pagos;

  double get pagado => _suma(pagos.map((pago) => pago.monto));

  /// El último cobro: en una orden pagada, el que la saldó. En `null` si no
  /// se ha cobrado nada.
  DateTime? get fechaPago => pagos.isEmpty ? null : pagos.last.fecha;

  /// Lo que falta por cobrar. Una cancelada ya no debe nada.
  double get saldo {
    if (cancelada) return 0;

    final saldo = total - pagado;
    return saldo > _margen ? saldo : 0;
  }

  EstadoPagoVenta get estado {
    if (cancelada) return EstadoPagoVenta.cancelado;
    if (saldo == 0) return EstadoPagoVenta.pagado;
    if (pagado > _margen) return EstadoPagoVenta.parcial;

    return EstadoPagoVenta.pendiente;
  }
}

/// El reporte general de ventas de un periodo: las órdenes recibidas en él y
/// lo que suman.
///
/// Las canceladas aparecen en la tabla, para que se vea que existieron, pero
/// no cuentan en ningún total: no son una venta ni algo que cobrar.
@immutable
class ReporteVentas {
  /// Las [ventas] pueden llegar en cualquier orden: aquí se ordenan por folio.
  ReporteVentas({
    required this.rango,
    required this.generado,
    required List<VentaReporte> ventas,
  }) : ventas = List.unmodifiable(
         ventas.sorted((a, b) => compararFolios(a.folio, b.folio)),
       );

  /// Las columnas de la tabla, en el PDF y en el Excel.
  static const columnas = [
    'Folio',
    'Total',
    'Pagado',
    'Estatus',
    'Saldo pendiente',
    'Fecha de pago',
  ];

  /// Las columnas del detalle de pagos, debajo del resumen.
  static const columnasPagos = ['Folio', 'Fecha y hora', 'Método', 'Monto'];

  final RangoReporte rango;

  /// Cuándo se sacó: el reporte de hoy cambia en cuanto entra otra orden.
  final DateTime generado;

  /// Por folio, del menor al mayor.
  final List<VentaReporte> ventas;

  Iterable<VentaReporte> get _vigentes => ventas.where((v) => !v.cancelada);

  int get canceladas => ventas.length - _vigentes.length;

  /// Lo que valen las órdenes del periodo.
  double get totalVendido => _suma(_vigentes.map((v) => v.total));

  /// Lo que ya entró. No es ganancia —la aplicación no lleva costos—: es lo
  /// que se cobró.
  double get cobrado => _suma(pagos.map((pago) => pago.monto));

  /// Lo que falta por cobrar de esas mismas órdenes.
  double get pendiente => _suma(_vigentes.map((v) => v.saldo));

  /// Cada cobro de las órdenes del periodo: por folio, como la tabla de
  /// órdenes, y los de una misma orden del más antiguo al más reciente. Los de
  /// las canceladas no entran, igual que en los totales.
  List<PagoReporte> get pagos => [
    for (final venta in _vigentes) ...venta.pagos,
  ];

  /// Lo cobrado por método de pago, sumando el detalle de pagos, en el orden
  /// en que la aplicación lista los métodos. Sólo los que tuvieron cobros.
  Map<MetodoPagoType, double> get cobradoPorMetodo {
    final totales = <MetodoPagoType, double>{};

    for (final pago in pagos) {
      totales[pago.metodo] = (totales[pago.metodo] ?? 0) + pago.monto;
    }

    return {
      for (final metodo in MetodoPagoType.values)
        if ((totales[metodo] ?? 0) > _margen) metodo: totales[metodo]!,
    };
  }
}

/// Ordena dos folios `AAMM-NNNN`: primero por año y mes, y luego por el
/// consecutivo como número, para que los viejos de cinco dígitos
/// (`2610-00012`) no se adelanten a los de cuatro (`2610-0002`).
///
/// Un folio que no tenga esa forma se compara como texto.
int compararFolios(String a, String b) {
  final (prefijoA, numeroA) = _partesDelFolio(a);
  final (prefijoB, numeroB) = _partesDelFolio(b);

  if (prefijoA != prefijoB || numeroA == null || numeroB == null) {
    return a.compareTo(b);
  }

  return numeroA.compareTo(numeroB);
}

(String, int?) _partesDelFolio(String folio) {
  final guion = folio.lastIndexOf('-');

  if (guion < 0) return (folio, null);

  return (folio.substring(0, guion), int.tryParse(folio.substring(guion + 1)));
}

double _suma(Iterable<double> importes) =>
    importes.fold(0, (suma, importe) => suma + importe);
