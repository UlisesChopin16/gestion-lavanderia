import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/home/home_tabs_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:gestion_lavanderia/ui/views/home/home_tabs_type.dart';

part 'home_view_model.freezed.dart';
part 'home_view_model.g.dart';

@freezed
sealed class HomeState with _$HomeState {
  const HomeState._();

  const factory HomeState({
    @Default(HomeTabsType.ordenes) HomeTabsType pestana,
    @Default(ThemeMode.system) ThemeMode themeMode,
  }) = _HomeState;

  int get indice => pestana.index;
}

/// La navegación de la aplicación y el modo del tema.
@riverpod
class HomeViewModel extends _$HomeViewModel {
  final _preferencias = instance<SharedPreferences>();

  static const _llaveTema = 'theme_mode';

  @override
  HomeState build() => HomeState(themeMode: _temaGuardado);

  /// El tema con el que se cerró la aplicación la última vez.
  ///
  /// Se lee aquí, de forma síncrona, porque las preferencias ya están
  /// resueltas en el contenedor: la versión anterior tenía un `getThemeMode`
  /// que `main` debía acordarse de llamar, y hasta entonces la aplicación se
  /// dibujaba con el tema equivocado y luego cambiaba de golpe.
  ThemeMode get _temaGuardado {
    final guardado = _preferencias.getString(_llaveTema);

    return ThemeMode.values.firstWhere(
      (modo) => modo.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  void seleccionarPestana(HomeTabsType pestana) {
    state = state.copyWith(pestana: pestana);
  }

  /// Avanza al siguiente modo: según el sistema, claro, oscuro y de vuelta.
  ///
  /// Se guarda el nombre de la constante y no su `toString`, para que
  /// renombrar algo en Flutter no invalide lo que ya está en el equipo.
  Future<void> cambiarTema() async {
    final modos = ThemeMode.values;
    final siguiente = modos[(state.themeMode.index + 1) % modos.length];

    state = state.copyWith(themeMode: siguiente);

    await _preferencias.setString(_llaveTema, siguiente.name);
  }
}
