import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/types/column_clientes_name.dart';

export 'package:gestion_lavanderia/types/column_clientes_name.dart';

part 'filtros_clientes.freezed.dart';
part 'filtros_clientes.g.dart';

@freezed
sealed class FiltrosClientes with _$FiltrosClientes {
  const FiltrosClientes._();
  const factory FiltrosClientes({
    @Default('') String nombre,
    @Default(false) bool ascendente,
    @Default(ColumnClientesName.fechaCreacion) ColumnClientesName ordenamiento,
  }) = _FiltrosClientes;

  factory FiltrosClientes.fromJson(Map<String, dynamic> json) =>
      _$FiltrosClientesFromJson(json);

  bool get haveFilters {
    return nombre.isNotEmpty ||
        ordenamiento != ColumnClientesName.fechaCreacion;
  }
}
