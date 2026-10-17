import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/models/data/ordenes/movimiento_data.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';

export 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
export 'package:gestion_lavanderia/models/data/ordenes/movimiento_data.dart';
export 'package:gestion_lavanderia/types/estatus_orden_type.dart';

part 'orden_detalle_data.freezed.dart';

/// Una orden completa: sus datos, su ropa y su historial de pagos.
///
/// Es la forma que la pantalla de detalle necesita y que ninguna tabla tiene:
/// cuatro tablas en un solo objeto, con la ropa y los movimientos anidados.
/// `OrdenesLocalDatasource.detalle` lo arma; los DAOs sólo devuelven filas.
///
/// Del cliente lleva los datos que la pantalla muestra y no un objeto anidado:
/// la orden necesita saber a quién es y cómo contactarlo, no administrar un
/// cliente.
// `makeCollectionsUnmodifiable: false` no es una preferencia: freezed 3.0.4
// genera para un campo de lista un parámetro `final` en el constructor, que no
// es Dart válido y no compila. Apagarlo deja la lista sin la vista inmutable,
// pero la igualdad sigue siendo por valor. Se puede quitar al subir a freezed 4,
// donde el generador ya no emite ese `final`.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class OrdenDetalleData with _$OrdenDetalleData {
  const OrdenDetalleData._();

  const factory OrdenDetalleData({
    required int id,
    required String folio,
    required int clienteId,

    /// Nombre y apellidos del cliente, ya unidos.
    required String cliente,
    @Default('') String clienteTelefono,
    @Default('') String clienteCorreo,
    String? descripcion,
    required EstatusOrdenType estatus,
    required double total,
    required double restante,
    required DateTime fechaCreacion,
    DateTime? fechaCierre,
    @Default(<ItemOrdenData>[]) List<ItemOrdenData> items,

    /// Los movimientos, del más reciente al más antiguo.
    @Default(<MovimientoData>[]) List<MovimientoData> historial,
  }) = _OrdenDetalleData;

  double get pagado => total - restante;

  bool get tieneSaldo => restante > 0;

  List<ItemOrdenData> get pendientes =>
      items.where((item) => item.estaPendiente).toList();

  int get pendientesPorEntregar => pendientes.length;

  /// Una orden sin renglones no cuenta como entregada: está vacía.
  bool get todoEntregado => items.isNotEmpty && pendientes.isEmpty;

  /// El movimiento más reciente, que es el que se corrige al guardar la orden
  /// sin registrar un abono nuevo.
  MovimientoData? get ultimoMovimiento => historial.firstOrNull;

  /// Lo que suman los renglones. Se compara con [total] para detectar una orden
  /// cuyo total quedó desalineado de su ropa.
  double get importeDeItems =>
      items.fold(0.0, (suma, item) => suma + item.importe);
}
