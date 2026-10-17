import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/types/columns_ordenes_names.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';

export 'package:gestion_lavanderia/types/columns_ordenes_names.dart';
export 'package:gestion_lavanderia/types/estatus_orden_type.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

part 'filtros_ordenes.freezed.dart';
part 'filtros_ordenes.g.dart';

@freezed
sealed class FiltrosOrdenes with _$FiltrosOrdenes {
  const FiltrosOrdenes._();

  /// [fechaInicio] y [fechaFin] son el rango del calendario sobre la fecha de
  /// creación de la orden. Cualquiera de los dos puede venir nulo: el rango
  /// puede estar abierto por un extremo, o no existir.
  ///
  /// Son dos campos y no una `List<DateTime?>` de dos posiciones para que el
  /// significado de cada fecha esté en su nombre y no en su índice.
  const factory FiltrosOrdenes({
    @Default('') String busqueda,
    @Default(EstatusOrdenType.todos) EstatusOrdenType estatus,
    @Default(false) bool ascendente,
    MetodoPagoType? metodoPago,
    @Default(ColumnsOrdenesNames.fechaCreacion)
    ColumnsOrdenesNames ordenamiento,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) = _FiltrosOrdenes;

  factory FiltrosOrdenes.fromJson(Map<String, dynamic> json) =>
      _$FiltrosOrdenesFromJson(json);

  bool get haveFilters {
    return busqueda.isNotEmpty ||
        estatus != EstatusOrdenType.todos ||
        ordenamiento != ColumnsOrdenesNames.fechaCreacion ||
        metodoPago != null ||
        fechaInicio != null ||
        fechaFin != null;
  }
}
