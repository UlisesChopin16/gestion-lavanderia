import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/core/assets/fonts.gen.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';

/// El tema de la aplicación, armado a partir del color que eligió la empresa.
///
/// Se construye con un color semilla y no con una paleta escrita a mano: con
/// nueve colores a elegir, cada uno necesitaría su juego de tonos para fondos,
/// bordes y texto. `ColorScheme.fromSeed` los deriva y garantiza que el
/// contraste del texto sobre cada superficie sea legible en los dos modos.
@immutable
class ThemeApp {
  const ThemeApp({this.seed = ColoresEmpresa.porOmision});

  final Color seed;

  ThemeData get light => _construir(Brightness.light);

  ThemeData get dark => _construir(Brightness.dark);

  ThemeData _construir(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final esOscuro = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      fontFamily: FontFamily.poppins,
      // El fondo es un tono distinto al de las tarjetas para que se despeguen
      // del lienzo sin necesidad de sombras marcadas.
      scaffoldBackgroundColor: esOscuro
          ? scheme.surface
          : scheme.surfaceContainer,
      extensions: [_rayado(scheme, esOscuro: esOscuro)],
      cardTheme: CardThemeData(
        color: esOscuro ? scheme.surfaceContainer : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      appBarTheme: AppBarTheme(
        elevation: 1,
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: esOscuro ? scheme.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esOscuro ? null : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        labelStyle: TextStyle(color: scheme.primary),
        errorStyle: TextStyle(color: scheme.error),
        // En reposo, sólo la raya de abajo. El campo enfocado pasa a marco, y
        // con él la etiqueta sube a cortar la línea: el cambio de acomodo es a
        // propósito, para que se vea en qué campo se está escribiendo. Con
        // error no se declara borde: queda el subrayado de Material, en color
        // de error.
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // `DropdownMenu` no toma el relleno del tema de los campos sino del
      // suyo, que lo trae apagado: sin esto, el desplegable quedaba como una
      // raya suelta junto a campos rellenos. Sólo se le pasa el relleno; lo
      // demás lo sigue tomando del tema de los campos que tenga encima, que
      // algunas pantallas ajustan.
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: esOscuro ? null : Colors.white,
        ),
      ),
      // La barra de módulos no es un `NavigationBar` sino botones propios,
      // que toman sus colores del esquema: no hay tema que configurar aquí.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esOscuro ? scheme.surface : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: esOscuro ? scheme.surfaceContainer : Colors.white,
        elevation: 15,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.primary, width: 0.5),
        ),
      ),
    );
  }

  /// El rayado de los listados.
  ///
  /// Se declara aquí y no en cada tabla porque la tabla de escritorio y las
  /// tarjetas de la vista compacta tienen que alternar con los mismos colores.
  ColorRowTheme _rayado(ColorScheme scheme, {required bool esOscuro}) {
    return ColorRowTheme(
      firstRowColor: esOscuro ? scheme.surfaceContainerLow : Colors.white,
      secondRowColor: esOscuro
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLow,
      hoverColor: scheme.primary.withValues(alpha: 0.12),
    );
  }
}
