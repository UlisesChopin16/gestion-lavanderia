import 'package:flutter/material.dart'
    show Brightness, ThemeMode, WidgetsBinding;
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

  /// Alterna entre claro y oscuro.
  ///
  /// Son los dos modos que se eligen; «según el sistema» queda sólo como el
  /// de arranque, mientras nadie ha dicho cuál quiere. Antes el botón iba
  /// dando la vuelta a los tres, y para pasar de claro a oscuro había que
  /// tocarlo dos veces.
  ///
  /// Se guarda el nombre de la constante y no su `toString`, para que
  /// renombrar algo en Flutter no invalide lo que ya está en el equipo.
  Future<void> cambiarTema() async {
    final siguiente = _seVeOscuro ? ThemeMode.light : ThemeMode.dark;

    state = state.copyWith(themeMode: siguiente);

    await _preferencias.setString(_llaveTema, siguiente.name);
  }

  /// Si lo que hay en pantalla es oscuro.
  ///
  /// Con «según el sistema» hay que preguntárselo al equipo: el estado dice
  /// que manda el sistema, no cuál de los dos puso. Sin eso, el primer toque
  /// en un equipo que ya está oscuro lo dejaría oscuro y parecería que el
  /// botón no hace nada.
  bool get _seVeOscuro => switch (state.themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };
}
