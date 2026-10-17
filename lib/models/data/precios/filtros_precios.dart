import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/types/clothe_size_type.dart';
import 'package:gestion_lavanderia/types/column_precios_name.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';

export 'package:gestion_lavanderia/types/clothe_size_type.dart';
export 'package:gestion_lavanderia/types/column_precios_name.dart';
export 'package:gestion_lavanderia/types/estatus_type.dart';

part 'filtros_precios.freezed.dart';
part 'filtros_precios.g.dart';

/// Valor de `FiltrosPrecios.categoriaId` cuando no se filtra por categoría.
///
/// Es una constante de nivel superior y no un miembro estático de
/// [FiltrosPrecios] porque freezed la copia sin calificar al generar los
/// valores por omisión del constructor.
const int sinCategoria = -1;

@freezed
sealed class FiltrosPrecios with _$FiltrosPrecios {
  const FiltrosPrecios._();

  /// [categoriaId] en [sinCategoria] significa "sin categoría seleccionada".
  const factory FiltrosPrecios({
    @Default('') String nombre,
    @Default(EstatusType.activo) EstatusType estatus,
    @Default(false) bool ascendente,
    @Default(sinCategoria) int categoriaId,
    ClotheSizeType? clotheSize,
    @Default(ColumnPreciosName.fechaCreacion) ColumnPreciosName ordenamiento,
  }) = _FiltrosPrecios;

  factory FiltrosPrecios.fromJson(Map<String, dynamic> json) =>
      _$FiltrosPreciosFromJson(json);

  bool get haveFilters {
    return nombre.isNotEmpty ||
        estatus != EstatusType.activo ||
        ordenamiento != ColumnPreciosName.fechaCreacion ||
        clotheSize != null ||
        categoriaId != sinCategoria;
  }
}
