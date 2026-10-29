import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Las cuentas de un cobro en efectivo: con cuánto paga el cliente, cuánto
/// se le devuelve y qué se guarda.
///
/// Vive aparte porque se cobra en dos pantallas —el adelanto del alta y el
/// cobro del detalle— y las dos tienen que decidir lo mismo. Duplicar estas
/// cuatro reglas es lo que acaba con una pantalla que acepta un billete que la
/// otra rechaza.
@immutable
class CobroEnEfectivo {
  const CobroEnEfectivo({
    required this.metodoPago,
    required this.abono,
    required this.recibido,
  });

  final MetodoPagoType metodoPago;

  /// Lo que se abona a la orden.
  final double abono;

  /// Con cuánto paga el cliente. Cero mientras no se escriba nada.
  final double recibido;

  /// Medio centavo: el mismo margen con el que la base da un saldo por cero.
  static const double margen = 0.005;

  /// Si hay efectivo que contar: un cobro en efectivo de algo. Sin abono no
  /// se entrega ningún billete, y con tarjeta no hay cambio.
  bool get aplica => metodoPago == MetodoPagoType.efectivo && abono > margen;

  double get cambio => recibido - abono;

  /// Si lo que entrega el cliente no alcanza. Sin nada escrito se da por
  /// pagado justo, que es el caso común: no se obliga a teclear el billete
  /// cuando el cliente paga exacto.
  bool get insuficiente => aplica && recibido > 0 && recibido + margen < abono;

  /// Lo que se guarda en el movimiento como recibido.
  ///
  /// Sin nada escrito se guarda el propio abono, por la misma regla con la que
  /// se valida —"no escribió nada" es "pagó justo"—: así el historial dice con
  /// cuánto se pagó en todos los cobros en efectivo, no sólo en los que dieron
  /// cambio.
  double? get aGuardar {
    if (!aplica) return null;

    return recibido > 0 ? recibido : abono;
  }
}
