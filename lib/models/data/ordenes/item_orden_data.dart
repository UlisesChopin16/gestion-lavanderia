import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

export 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

part 'item_orden_data.freezed.dart';

/// Un renglón de ropa de una orden, con el concepto de precio que lo originó.
///
/// El concepto viaja anidado y no aplanado porque es el mismo [PrecioData] que
/// usa la pantalla de precios: así el renglón de una orden y la lista de precios
/// muestran el concepto de una sola forma.
@freezed
sealed class ItemOrdenData with _$ItemOrdenData {
  const ItemOrdenData._();

  const factory ItemOrdenData({
    /// `0` mientras el renglón no se ha guardado.
    @Default(0) int id,
    @Default(0) int ordenId,
    required PrecioData precio,
    @Default(1.0) double cantidad,

    /// Lo que cuesta el renglón. Quien crea ropa no tiene que calcularlo:
    /// `OrdenesLocalDatasource` lo recalcula con [PrecioData.importePor] antes
    /// de guardar, para que el total de la orden no pueda discrepar de su ropa.
    @Default(0.0) double importe,
    @Default(false) bool estaEntregado,
    required DateTime fechaEntrega,

    /// Cuándo se entregó realmente; nulo mientras no se entregue.
    DateTime? fechaEntregado,

    /// Movimiento del historial en el que se entregó; nulo mientras no se
    /// entregue.
    int? ordenHistoryId,
  }) = _ItemOrdenData;

  bool get esNuevo => id == 0;

  String get concepto => precio.descripcion;

  /// Si el renglón sigue pendiente de salir.
  bool get estaPendiente => !estaEntregado;
}
