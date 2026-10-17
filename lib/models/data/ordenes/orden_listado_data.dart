import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

export 'package:gestion_lavanderia/types/estatus_orden_type.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

part 'orden_listado_data.freezed.dart';

/// Un renglón de la lista de órdenes: la orden, el nombre de su cliente y el
/// método de pago de su último movimiento.
///
/// Las tres tablas llegan aplanadas porque la lista las muestra en una sola
/// fila. El detalle de la orden, con la ropa y el historial anidados, es
/// `OrdenDetalleData`.
@freezed
sealed class OrdenListadoData with _$OrdenListadoData {
  const OrdenListadoData._();

  const factory OrdenListadoData({
    required int id,
    required String folio,
    required int clienteId,

    /// Nombre y apellidos del cliente, ya unidos.
    required String cliente,
    String? descripcion,
    required EstatusOrdenType estatus,
    required double total,
    required double restante,

    /// Método de pago del último movimiento, que es el que la lista muestra.
    required MetodoPagoType metodoPago,
    required DateTime fechaCreacion,
    DateTime? fechaCierre,

    /// Fecha del último movimiento: cuándo se tocó la orden por última vez.
    required DateTime ultimaInteraccion,
  }) = _OrdenListadoData;

  double get pagado => total - restante;

  bool get tieneSaldo => restante > 0;

  bool get estaCerrada => estatus == EstatusOrdenType.cerrada;
}
