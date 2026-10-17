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
    @Default(EstatusType.activo) EstatusType estatus,
    @Default(false) bool ascendente,
    @Default(ColumnsCategoriaType.fechaCreacion)
    ColumnsCategoriaType ordenamiento,
  }) = _FiltrosCategoria;

  factory FiltrosCategoria.fromJson(Map<String, dynamic> json) =>
      _$FiltrosCategoriaFromJson(json);

  bool get haveFilters {
    return nombre.isNotEmpty ||
        estatus != EstatusType.activo ||
        ordenamiento != ColumnsCategoriaType.fechaCreacion;
  }
}
