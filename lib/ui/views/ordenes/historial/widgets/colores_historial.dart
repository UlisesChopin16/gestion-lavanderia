import 'package:flutter/material.dart';

/// Los colores del historial que cambian entre el modo claro y el oscuro.
///
/// En oscuro, una tarjeta se distingue por su fondo: un gris un poco más claro
/// que el del diálogo. En claro ese mismo recurso se veía como bloques grises
/// sobre blanco, pesados; ahí la tarjeta lleva un fondo apenas teñido y un
/// borde fino, que la despega sin ensuciarla.
///
/// Y los colores de estado —el verde del dinero, el azul de la ropa, el
/// naranja de lo pendiente— son los de Material, pensados para fondos
/// oscuros: sobre blanco, un texto en `Colors.green` casi no se lee. En claro
/// se oscurecen.
extension ColoresHistorial on ColorScheme {
  bool get _claro => brightness == Brightness.light;

  /// [color] con el contraste suficiente para usarse en texto e iconos sobre
  /// el fondo del diálogo.
  Color legible(Color color) =>
      _claro ? Color.lerp(color, Colors.black, 0.3)! : color;

  Color get fondoTarjeta => _claro ? surfaceContainerLow : surfaceContainerHigh;

  /// En oscuro no hace falta: el fondo ya despega la tarjeta.
  Color? get bordeTarjeta =>
      _claro ? outlineVariant.withValues(alpha: 0.7) : null;

  /// La celda de una prenda, dentro del recuadro teñido de lo entregado.
  Color get fondoCelda =>
      _claro ? surfaceContainerLowest : surfaceContainerHighest;

  /// Cuánto se tiñe un fondo con un color de estado. En claro menos: sobre
  /// blanco el mismo tinte se ve el doble.
  double get tinte => _claro ? 0.06 : 0.08;
}
