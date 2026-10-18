import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/types/columns_categoria_type.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';

export 'package:gestion_lavanderia/types/columns_categoria_type.dart';
export 'package:gestion_lavanderia/types/estatus_type.dart';

part 'filtros_categoria.freezed.dart';
part 'filtros_categoria.g.dart';

@freezed
sealed class FiltrosCategoria with _$FiltrosCategoria {
  const FiltrosCategoria._();
  const factory FiltrosCategoria({
    @Default('') String nombre,

    /// En `null` no se filtra por estatus: se ven las activas y las dadas de
    /// baja. El listado arranca en [porOmision], que son sólo las activas.
    EstatusType? estatus,
    @Default(false) bool ascendente,
    @Default(ColumnsCategoriaType.fechaCreacion)
    ColumnsCategoriaType ordenamiento,
  }) = _FiltrosCategoria;

  factory FiltrosCategoria.fromJson(Map<String, dynamic> json) =>
      _$FiltrosCategoriaFromJson(json);

  /// Los filtros con los que nace el listado, y a los que vuelve al limpiarlos.
  ///
  /// El estatus por omisión no se pone como valor del constructor: entonces
  /// "sin estatus" —ver todos— no se podría distinguir al releer los filtros
  /// guardados de "aquí no había nada", y quitar el filtro se desharía solo al
  /// cerrar la aplicación.
  static const porOmision = FiltrosCategoria(
    estatus: EstatusType.activo,
  );

  bool get haveFilters {
    return nombre.isNotEmpty ||
        estatus != EstatusType.activo ||
        ordenamiento != ColumnsCategoriaType.fechaCreacion;
  }
}
