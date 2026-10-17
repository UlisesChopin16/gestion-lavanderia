import 'package:drift/drift.dart';

/// Construye el `OR` de un `LIKE` insensible a mayúsculas sobre varias
/// columnas.
///
/// Centraliza el patrón `col.lower().like('%texto%') | ...` para que la
/// búsqueda por texto sea igual en todos los DAOs.
Expression<bool> likeAny(String texto, List<Expression<String>> columnas) {
  assert(columnas.isNotEmpty, 'Se requiere al menos una columna de búsqueda');

  final patron = '%${texto.trim().toLowerCase()}%';
  return columnas
      .map((columna) => columna.lower().like(patron))
      .reduce((a, b) => a | b);
}

/// Igual que [likeAny], pero exige que *todas* las palabras del texto aparezcan
/// en alguna de las columnas. Permite buscar "juan perez" y encontrar al
/// cliente aunque nombre y apellido estén en columnas distintas.
Expression<bool> likeAllWords(
  String texto,
  List<Expression<String>> columnas,
) {
  final palabras = texto
      .trim()
      .split(RegExp(r'\s+'))
      .where((palabra) => palabra.isNotEmpty);
  if (palabras.isEmpty) return likeAny(texto, columnas);

  return palabras
      .map((palabra) => likeAny(palabra, columnas))
      .reduce((a, b) => a & b);
}
