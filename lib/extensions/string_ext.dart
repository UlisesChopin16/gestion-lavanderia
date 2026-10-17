extension StringExt on String {
  /// Sin espacios en los extremos y con los interiores reducidos a uno.
  ///
  /// Se aplica antes de guardar un nombre para que "Juan  Pérez" y
  /// "Juan Pérez " no se guarden como dos clientes distintos.
  String normalizeSpaces() => trim().replaceAll(RegExp(r'\s+'), ' ');

  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  bool get isEmail =>
      RegExp(r'^[\w\.-]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(this);

  bool get isOnlyNumbers => RegExp(r'^[0-9]+$').hasMatch(this);
}

/// Las mismas operaciones cuando el texto puede faltar, para no repetir la
/// comprobación de nulo en cada campo del formulario. Un texto ausente se
/// trata como vacío.
extension StringNullExt on String? {
  String normalizeSpaces() => (this ?? '').normalizeSpaces();

  String capitalize() => (this ?? '').capitalize();

  bool get isEmail => (this ?? '').isEmail;

  bool get isOnlyNumbers => (this ?? '').isOnlyNumbers;
}
