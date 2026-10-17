/// Unidad en la que se cobra un concepto de precio.
enum UnitType {
  pieza(value: 'Pieza', plural: 'Piezas'),
  kilo(value: 'Kg', plural: 'Kgs'),
  litro(value: 'Litro', plural: 'Litros'),
  metro(value: 'Metro', plural: 'Metros'),
  gramo(value: 'Gramo', plural: 'Gramos'),
  miligramo(value: 'Miligramo', plural: 'Miligramos'),
  mililitro(value: 'Mililitro', plural: 'Mililitros');

  final String value;
  final String plural;

  const UnitType({required this.value, required this.plural});

  factory UnitType.fromString(String value) {
    return UnitType.values.firstWhere(
      (unit) => unit.value == value,
      orElse: () => UnitType.pieza,
    );
  }
}
