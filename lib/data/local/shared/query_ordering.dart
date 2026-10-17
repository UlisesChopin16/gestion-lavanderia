import 'package:drift/drift.dart';

/// Traduce el ordenamiento elegido en los filtros a los `OrderingTerm` de la
/// consulta.
///
/// Con el mapa, agregar una columna ordenable es agregar una entrada: la
/// relación "enum de columna -> columna de la tabla" queda declarada en un solo
/// lugar y no se puede desalinear.
///
/// [desempate] se agrega siempre como criterio secundario para que el orden sea
/// estable cuando la columna elegida tiene valores repetidos (o nulos); sin él,
/// SQLite puede devolver los empates en cualquier orden y la lista "salta"
/// entre una consulta y la siguiente.
List<OrderingTerm> buildOrdering<T extends Object>({
  required T ordenamiento,
  required Map<T, Expression<Object>> columnas,
  required bool ascendente,
  Expression<Object>? desempate,
}) {
  final mode = ascendente ? OrderingMode.asc : OrderingMode.desc;
  final columna = columnas[ordenamiento];

  return [
    if (columna != null) OrderingTerm(expression: columna, mode: mode),
    if (desempate != null) OrderingTerm(expression: desempate, mode: mode),
  ];
}

extension SimpleSelectOrdering<T extends HasResultSet, D>
    on SimpleSelectStatement<T, D> {
  /// Aplica términos ya construidos a un `select` simple, cuyo `orderBy`
  /// espera funciones en lugar de expresiones.
  void orderByTerms(List<OrderingTerm> terms) {
    if (terms.isEmpty) return;
    orderBy(terms.map((term) => (T _) => term).toList());
  }
}
