import 'package:flutter/material.dart';

/// Colores de las filas alternadas de un listado.
///
/// Vive en el tema y no en la tabla porque el mismo rayado se usa en la tabla
/// de escritorio y en las tarjetas de la vista compacta: si cada una eligiera
/// su color, el listado cambiaría de aspecto al cambiar el ancho de la ventana.
@immutable
class ColorRowTheme extends ThemeExtension<ColorRowTheme> {
  const ColorRowTheme({
    required this.firstRowColor,
    required this.secondRowColor,
    required this.hoverColor,
  });

  /// Rayado derivado del esquema de color.
  ///
  /// Permite usar la tabla antes de registrar la extensión en el tema y sirve
  /// de valor por omisión en [of]: sin esto, un tema sin la extensión dejaba
  /// las filas sin color y el error pasaba desapercibido.
  factory ColorRowTheme.fromScheme(ColorScheme scheme) => ColorRowTheme(
    firstRowColor: scheme.surface,
    secondRowColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    hoverColor: scheme.primary.withValues(alpha: 0.12),
  );

  final Color firstRowColor;
  final Color secondRowColor;

  /// Color de la fila bajo el cursor. Es translúcido para que se mezcle con el
  /// rayado en lugar de taparlo.
  final Color hoverColor;

  /// La extensión del tema, o un rayado derivado del esquema de color.
  static ColorRowTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ColorRowTheme>() ??
        ColorRowTheme.fromScheme(theme.colorScheme);
  }

  /// Color de la fila [index], contando desde cero.
  Color colorForRow(int index) => index.isEven ? firstRowColor : secondRowColor;

  @override
  ColorRowTheme copyWith({
    Color? firstRowColor,
    Color? secondRowColor,
    Color? hoverColor,
  }) {
    return ColorRowTheme(
      firstRowColor: firstRowColor ?? this.firstRowColor,
      secondRowColor: secondRowColor ?? this.secondRowColor,
      hoverColor: hoverColor ?? this.hoverColor,
    );
  }

  @override
  ColorRowTheme lerp(covariant ThemeExtension<ColorRowTheme>? other, double t) {
    if (other is! ColorRowTheme) return this;

    return ColorRowTheme(
      firstRowColor: Color.lerp(firstRowColor, other.firstRowColor, t)!,
      secondRowColor: Color.lerp(secondRowColor, other.secondRowColor, t)!,
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t)!,
    );
  }
}
