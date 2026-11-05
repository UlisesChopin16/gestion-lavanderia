import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart'
    show compararFolios;

/// Cuánto tiempo lleva una orden debiendo, contado desde que se recibió.
///
/// Tres grupos y no días sueltos: lo que importa es a quién llamar primero,
/// y eso lo dice el grupo.
enum AntiguedadSaldo {
  semana(titulo: 'Menos de una semana', corto: 'Esta semana'),
  mes(titulo: 'De una semana a un mes', corto: 'Hasta un mes'),
  masDeUnMes(titulo: 'Más de un mes', corto: 'Más de un mes');

  const AntiguedadSaldo({required this.titulo, required this.corto});

  final String titulo;

  /// Para las etiquetas de los filtros.
  final String corto;

  /// El grupo de una orden recibida hace [dias] días.
  static AntiguedadSaldo de(int dias) => switch (dias) {
    < 7 => semana,
    <= 30 => mes,
    _ => masDeUnMes,
  };
}

/// Una orden que todavía debe algo.
@immutable
class SaldoPendiente {
  const SaldoPendiente({
    required this.folio,
    required this.clienteId,
    required this.cliente,
    required this.telefono,
    required this.recibida,
    required this.total,
    required this.saldo,
  });

  final String folio;
  final int clienteId;
  final String cliente;
  final String telefono;
  final DateTime recibida;
  final double total;

  /// Lo que falta por cobrar.
  final double saldo;

  double get pagado => total - saldo;

  /// Cuántos días completos van desde que se recibió hasta [hoy].
  int diasHasta(DateTime hoy) => _dias(recibida, hoy);

  AntiguedadSaldo antiguedadAl(DateTime hoy) =>
      AntiguedadSaldo.de(diasHasta(hoy));
}

/// Lo que debe un cliente, sumando todas sus órdenes con saldo.
typedef DeudaDeCliente = ({
  String cliente,
  String telefono,
  double saldo,
  int ordenes,
});

/// Lo que agrupa un [AntiguedadSaldo]: cuánto se debe y en cuántas órdenes.
typedef SaldoPorAntiguedad = ({double saldo, int ordenes});

/// Las cuentas por cobrar: todas las órdenes que deben algo, y cuánto lleva
/// cada una debiendo.
@immutable
class CuentasPorCobrar {
  /// Los [saldos] pueden llegar en cualquier orden: aquí se ordenan por
  /// folio.
  CuentasPorCobrar({required this.hoy, required List<SaldoPendiente> saldos})
    : saldos = List.unmodifiable(
        saldos.sorted((a, b) => compararFolios(a.folio, b.folio)),
      );

  /// Contra qué día se cuenta la antigüedad.
  final DateTime hoy;

  final List<SaldoPendiente> saldos;

  double get total => saldos.map((s) => s.saldo).sum;

  /// La que lleva más tiempo debiendo, por su fecha y no por su folio: el
  /// folio casi siempre sigue a la fecha, pero nada lo obliga. En `null` si
  /// nadie debe.
  SaldoPendiente? get masAntigua => minBy(saldos, (s) => s.recibida);

  /// Cuántos clientes distintos deben algo.
  int get clientes => saldos.map((s) => s.clienteId).toSet().length;

  /// Los tres grupos, siempre en su orden y aunque alguno esté vacío.
  Map<AntiguedadSaldo, SaldoPorAntiguedad> get porAntiguedad {
    final grupos = groupBy(saldos, (s) => s.antiguedadAl(hoy));

    return {
      for (final antiguedad in AntiguedadSaldo.values)
        antiguedad: (
          saldo: (grupos[antiguedad] ?? const []).map((s) => s.saldo).sum,
          ordenes: grupos[antiguedad]?.length ?? 0,
        ),
    };
  }

  /// Los clientes que más deben, del que más al que menos.
  List<DeudaDeCliente> clientesQueMasDeben({int cuantos = 5}) {
    final porCliente = groupBy(saldos, (s) => s.clienteId);

    return [
      for (final saldos in porCliente.values)
        (
          cliente: saldos.first.cliente,
          telefono: saldos.first.telefono,
          saldo: saldos.map((s) => s.saldo).sum,
          ordenes: saldos.length,
        ),
    ].sorted((a, b) => b.saldo.compareTo(a.saldo)).take(cuantos).toList();
  }

  /// Las órdenes de un grupo, o todas si [antiguedad] es `null`.
  List<SaldoPendiente> de(AntiguedadSaldo? antiguedad) => antiguedad == null
      ? saldos
      : saldos.where((s) => s.antiguedadAl(hoy) == antiguedad).toList();
}

/// Días de calendario entre dos fechas, sin contar la hora: una orden de
/// anoche lleva un día aunque no hayan pasado veinticuatro horas.
int _dias(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;
