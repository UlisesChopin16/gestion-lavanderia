import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

export 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

part 'movimiento_data.freezed.dart';

/// Un movimiento del historial de una orden con la ropa que salió en él.
///
/// La ropa viene anidada porque el historial no guarda una copia de los
/// renglones: cada item dice a qué movimiento pertenece su entrega, y es lo que
/// permite reconstruir qué se entregó en cada momento.
// `makeCollectionsUnmodifiable: false` no es una preferencia: freezed 3.0.4
// genera para un campo de lista un parámetro `final` en el constructor, que no
// es Dart válido y no compila. Apagarlo deja la lista sin la vista inmutable,
// pero la igualdad sigue siendo por valor. Se puede quitar al subir a freezed 4,
// donde el generador ya no emite ese `final`.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class MovimientoData with _$MovimientoData {
  const MovimientoData._();

  const factory MovimientoData({
    /// `0` mientras el movimiento no se ha guardado.
    @Default(0) int id,
    @Default(0) int ordenId,

    /// Importe abonado en este movimiento.
    @Default(0.0) double monto,

    /// Saldo de la orden después de este movimiento.
    @Default(0.0) double restante,
    @Default(MetodoPagoType.efectivo) MetodoPagoType metodoPago,

    /// Con cuánto pagó el cliente cuando pagó en efectivo. Nulo en cualquier
    /// otro caso, y en los pagos de antes de que se guardara.
    double? recibido,

    required DateTime fecha,

    /// Los renglones entregados en este movimiento. Vacío si sólo se abonó.
    @Default(<ItemOrdenData>[]) List<ItemOrdenData> entregados,
  }) = _MovimientoData;

  /// Lo cobrado en el movimiento no tiene por qué cubrir lo que salió: se puede
  /// entregar ropa sin abonar y abonar sin entregar.
  bool get huboEntrega => entregados.isNotEmpty;

  bool get huboAbono => monto > 0;

  /// Lo que se le devolvió al cliente, cuando se sabe con cuánto pagó.
  double? get cambio {
    final recibido = this.recibido;
    return recibido == null ? null : recibido - monto;
  }
}
