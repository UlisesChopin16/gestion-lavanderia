import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';

export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Medio centavo, el mismo margen con el que la base da un saldo por cero.
const double _margen = 0.005;

/// Un cobro del día en el corte de caja: un renglón del detalle.
@immutable
class CobroCorte {
  const CobroCorte({
    required this.folio,
    required this.cliente,
    required this.fecha,
    required this.metodo,
    required this.monto,
    this.recibido,
  });

  final String folio;
  final String cliente;
  final DateTime fecha;
  final MetodoPagoType metodo;

  /// Lo que se abonó a la orden.
  final double monto;

  /// Con cuánto pagó el cliente, cuando fue en efectivo. Nulo en los demás
  /// métodos y en los cobros de antes de que se guardara.
  final double? recibido;

  bool get enEfectivo => metodo == MetodoPagoType.efectivo;

  /// Lo que el cliente entregó en efectivo, o `null` si no pagó en efectivo.
  /// Un cobro en efectivo sin [recibido] se toma como pagado justo: es lo
  /// único que se sabe de él.
  double? get entregado => enEfectivo ? (recibido ?? monto) : null;

  /// El cambio que salió de la caja, o `null` si no pagó en efectivo.
  double? get cambio {
    final entregado = this.entregado;
    return entregado == null ? null : entregado - monto;
  }
}

/// El corte de caja de un día: lo que se cobró ese día, sin importar cuándo
/// se recibió la orden.
///
/// Es distinto del reporte de ventas, que va por las órdenes recibidas en el
/// periodo: el abono de hoy a una orden de la semana pasada está en el corte
/// de hoy, porque es dinero que entró hoy a la caja.
@immutable
class CorteCaja {
  /// Los [cobros] pueden llegar en cualquier orden: aquí se ordenan por folio
  /// y, los de una misma orden, por hora.
  CorteCaja({
    required this.dia,
    required this.generado,
    required List<CobroCorte> cobros,
  }) : cobros = List.unmodifiable(
         cobros.sorted((a, b) {
           final porFolio = compararFolios(a.folio, b.folio);
           return porFolio != 0 ? porFolio : a.fecha.compareTo(b.fecha);
         }),
       );

  /// Las columnas del detalle de cobros.
  static const columnas = [
    'Folio',
    'Hora',
    'Cliente',
    'Método',
    'Monto',
    'Pagó con',
    'Cambio',
  ];

  /// A medianoche: el corte es de un día entero.
  final DateTime dia;

  final DateTime generado;
  final List<CobroCorte> cobros;

  double get total => _suma(cobros.map((cobro) => cobro.monto));

  /// En cuántas órdenes distintas se cobró.
  int get ordenes => cobros.map((cobro) => cobro.folio).toSet().length;

  Iterable<CobroCorte> get _enEfectivo => cobros.where((c) => c.enEfectivo);

  /// Lo que se cobró en efectivo: lo que debe haber en la caja, además del
  /// fondo con el que se abrió.
  double get efectivoCobrado => _suma(_enEfectivo.map((c) => c.monto));

  /// Lo que los clientes entregaron en efectivo, antes de darles su cambio.
  double get efectivoRecibido => _suma(_enEfectivo.map((c) => c.entregado!));

  double get cambioEntregado => efectivoRecibido - efectivoCobrado;

  /// Lo cobrado en cada hora del día —la 9 es de 9:00 a 9:59—, sólo las que
  /// tuvieron cobros.
  Map<int, double> get porHora {
    final totales = <int, double>{};

    for (final cobro in cobros) {
      final hora = cobro.fecha.hour;
      totales[hora] = (totales[hora] ?? 0) + cobro.monto;
    }

    return totales;
  }

  /// Lo cobrado por método de pago, en el orden en que la aplicación lista
  /// los métodos. Sólo los que tuvieron cobros; un cobro viejo con crédito
  /// sale como crédito.
  Map<MetodoPagoType, double> get porMetodo {
    final totales = <MetodoPagoType, double>{};

    for (final cobro in cobros) {
      totales[cobro.metodo] = (totales[cobro.metodo] ?? 0) + cobro.monto;
    }

    return {
      for (final metodo in MetodoPagoType.values)
        if ((totales[metodo] ?? 0) > _margen) metodo: totales[metodo]!,
    };
  }
}

double _suma(Iterable<double> importes) =>
    importes.fold(0, (suma, importe) => suma + importe);

/// Lo cobrado en un día, para comparar el del corte con los anteriores.
typedef CobradoDelDia = ({DateTime dia, double total});

/// Lo que enseña la pantalla del corte de caja: el corte del día y lo que se
/// cobró en los días anteriores, para ver si fue un buen día.
@immutable
class EstadisticasCorte {
  const EstadisticasCorte({required this.corte, required this.semana});

  /// Cuántos días se comparan, contando el del corte.
  static const dias = 7;

  final CorteCaja corte;

  /// Lo cobrado en cada uno de los [dias] que terminan en el del corte, del
  /// más antiguo al más reciente: el último es el del corte. Los días sin
  /// cobros van en cero.
  final List<CobradoDelDia> semana;

  /// Cuánto cambió lo cobrado contra el día anterior, como fracción
  /// (`0.12` es 12 % más), o `null` si el anterior no se cobró nada y no hay
  /// contra qué comparar.
  double? get cambioContraAyer {
    if (semana.length < 2) return null;

    final ayer = semana[semana.length - 2].total;
    if (ayer <= _margen) return null;

    return (corte.total - ayer) / ayer;
  }
}
