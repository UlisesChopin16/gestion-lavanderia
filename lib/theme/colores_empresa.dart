import 'package:flutter/material.dart';

/// La paleta entre la que la empresa elige el color de su marca.
///
/// Son constantes `Color` y no los `MaterialColor` de `Colors`, porque
/// `ColorSwatch` compara también el tipo en su `==`: `Colors.blue` y
/// `Color(0xFF2196F3)` son el mismo color y aun así no son iguales, y el
/// selector de la paleta no reconocería el color ya guardado.
abstract final class ColoresEmpresa {
  static const purple = Color(0xFF9C27B0);
  static const deepPurple = Color(0xFF673AB7);
  static const indigo = Color(0xFF3F51B5);
  static const blue = Color(0xFF2196F3);
  static const lightBlue = Color(0xFF03A9F4);
  static const cyan = Color(0xFF00BCD4);
  static const teal = Color(0xFF009688);
  static const green = Color(0xFF4CAF50);
  static const amber = Color(0xFFFFC107);

  /// El color con el que nace una configuración nueva.
  static const porOmision = blue;

  static const values = <Color>[
    purple,
    deepPurple,
    indigo,
    blue,
    lightBlue,
    cyan,
    teal,
    green,
    amber,
  ];
}
