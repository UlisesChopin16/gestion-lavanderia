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

    /// En `null` no se filtra por estatus: se ven los activos y los dados de
    /// baja. El listado arranca en [porOmision], que son sólo los activos.
    EstatusType? estatus,
    @Default(false) bool ascendente,
    @Default(sinCategoria) int categoriaId,
    ClotheSizeType? clotheSize,
    @Default(ColumnPreciosName.fechaCreacion) ColumnPreciosName ordenamiento,
  }) = _FiltrosPrecios;

  factory FiltrosPrecios.fromJson(Map<String, dynamic> json) =>
      _$FiltrosPreciosFromJson(json);

  /// Los filtros con los que nace el listado, y a los que vuelve al limpiarlos.
  ///
  /// El estatus por omisión no se pone como valor del constructor: entonces
  /// "sin estatus" —ver todos— no se podría distinguir al releer los filtros
  /// guardados de "aquí no había nada", y quitar el filtro se desharía solo al
  /// cerrar la aplicación.
  static const porOmision = FiltrosPrecios(estatus: EstatusType.activo);

  bool get haveFilters {
    return nombre.isNotEmpty ||
        estatus != EstatusType.activo ||
        ordenamiento != ColumnPreciosName.fechaCreacion ||
        clotheSize != null ||
        categoriaId != sinCategoria;
  }
}
