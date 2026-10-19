import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/extensions/int_ext.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';

export 'package:gestion_lavanderia/types/estatus_type.dart';

part 'categoria_data.freezed.dart';

/// Una categoría de ropa, tal como la usan las pantallas.
///
/// No sabe nada de drift: la conversión en los dos sentidos vive en
/// `lib/data/local/categorias/categoria_data_mapper.dart`, del lado de los
/// datos. Así la interfaz habla de categorías y no de filas, y cambiar la
/// tabla no obliga a tocar lo que se dibuja.
@freezed
sealed class CategoriaData with _$CategoriaData {
  const CategoriaData._();

  const factory CategoriaData({
    /// `0` mientras la categoría no se ha guardado.
    @Default(0) int id,
    @Default('') String nombre,
    @Default(EstatusType.activo) EstatusType estatus,

    /// Días de entrega por omisión para los conceptos de esta categoría.
    @Default(0) int diasEntrega,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    DateTime? fechaEliminacion,
  }) = _CategoriaData;

  bool get esNueva => id == 0;

  bool get estaActiva => estatus == EstatusType.activo;

  /// Los días de entrega con su unidad: `1 día`, `3 días`.
  String get diasFormato => diasEntrega.enDias;

  /// Cómo se nombra la categoría en un selector: una dada de baja se puede
  /// seguir eligiendo como filtro, y hay que poder distinguirla.
  String get descripcion => estaActiva ? nombre : '$nombre (inactiva)';
}
