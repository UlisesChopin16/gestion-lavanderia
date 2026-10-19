extension IntExt on int {
  /// El número con su unidad en días: `1 día`, `3 días`.
  ///
  /// Está aquí y no en cada pantalla porque los días de entrega se escriben en
  /// varias —el catálogo de conceptos, el de categorías y, más adelante, la
  /// fecha prometida de una orden—, y el singular es fácil de olvidar en una
  /// de ellas.
  String get enDias => this == 1 ? '1 día' : '$this días';
}
