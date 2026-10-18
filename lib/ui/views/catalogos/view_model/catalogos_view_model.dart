import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/catalogos_tabs_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/ui/views/catalogos/catalogos_tabs_type.dart';

part 'catalogos_view_model.freezed.dart';
part 'catalogos_view_model.g.dart';

@freezed
sealed class CatalogosState with _$CatalogosState {
  const factory CatalogosState({
    @Default(CatalogosTabsType.clientes) CatalogosTabsType pestana,
  }) = _CatalogosState;
}

/// Qué catálogo está abierto.
///
/// La pestaña vive aquí y no en el estado de la pantalla porque un catálogo
/// puede mandar a otro: desde una categoría se piden sus conceptos, y eso
/// abre la pestaña de precios ya filtrada. Con el controlador de la barra como
/// única fuente de la verdad, ese salto obligaría a pasarlo de mano en mano
/// hasta el botón que lo pide.
@riverpod
class CatalogosViewModel extends _$CatalogosViewModel {
  @override
  CatalogosState build() => const CatalogosState();

  void abrir(CatalogosTabsType pestana) {
    if (pestana == state.pestana) return;

    state = state.copyWith(pestana: pestana);
  }
}
