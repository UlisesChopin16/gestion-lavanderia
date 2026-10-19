import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/extensions/int_ext.dart';
import 'package:gestion_lavanderia/types/clothe_size_type.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';

export 'package:gestion_lavanderia/types/clothe_size_type.dart';
export 'package:gestion_lavanderia/types/estatus_type.dart';
export 'package:gestion_lavanderia/types/unit_type.dart';

part 'precio_data.freezed.dart';

/// Un concepto de precio con el nombre de su categoría.
///
/// Existe porque la forma que necesita la interfaz no es la de la tabla: toda
/// pantalla de precios muestra el concepto junto al nombre de su categoría, que
/// vive en otra tabla. Una categoría o un cliente, que sí se consumen tal cual,
/// viajan como la fila generada y no tienen un modelo propio: un gemelo campo
/// por campo sólo agrega un mapeo que el compilador no puede verificar.
///
/// No sabe nada de drift. La conversión en los dos sentidos vive en
/// `lib/data/local/precios/precio_data_mapper.dart`, del lado de los datos, para
/// que este archivo no dependa de la base.
@freezed
sealed class PrecioData with _$PrecioData {
  const PrecioData._();

  const factory PrecioData({
    /// `0` mientras el concepto no se ha guardado.
    @Default(0) int id,
    required int categoriaId,

    /// Nombre de la categoría. Es de sólo lectura: al guardar no se escribe,
    /// porque la categoría se referencia por [categoriaId].
    required String categoria,
    required String nombreConcepto,
    @Default(ClotheSizeType.emptySize) ClotheSizeType clotheSize,
    @Default(0) int diasEntrega,
    @Default(UnitType.pieza) UnitType tipoUnidad,
    @Default(0.0) double importe,
    @Default(EstatusType.activo) EstatusType estatus,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    DateTime? fechaEliminacion,
  }) = _PrecioData;

  bool get esNuevo => id == 0;

  bool get estaActivo => estatus == EstatusType.activo;

  /// Los días de entrega con su unidad: `1 día`, `3 días`.
  ///
  /// Es un getter y no un campo guardado: el dato es [diasEntrega], que es con
  /// el que se calculan las fechas, y un campo aparte podría quedarse
  /// desfasado del número que dice representar.
  String get diasFormato => diasEntrega.enDias;

  /// Cómo se nombra el concepto en una lista: el tamaño sólo aparece cuando lo
  /// tiene.
  String get descripcion => clotheSize == ClotheSizeType.emptySize
      ? nombreConcepto
      : '$nombreConcepto - ${clotheSize.description}';

  /// Lo que cuestan [cantidad] unidades de este concepto.
  ///
  /// El importe de un renglón de orden se calcula aquí y no en cada pantalla,
  /// para que la lista, el total de la orden y el ticket no puedan discrepar.
  double importePor(double cantidad) => importe * cantidad;
}
