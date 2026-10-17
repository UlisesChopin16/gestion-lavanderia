/// Contrato de un enum de columnas ordenables.
///
/// Clientes, categorías, precios y órdenes se ordenan cada uno por su propio
/// enum. El contrato existe para que la tabla y el desplegable de ordenamiento
/// reciban cualquiera de ellos sin una copia por módulo: lo único que necesitan
/// de la columna es el texto que ve el usuario.
abstract interface class SortableColumn {
  /// Encabezado de la columna, tal como se muestra en la interfaz.
  String get title;
}
