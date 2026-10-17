/// Columnas por las que puede ordenarse la lista de categorías.
enum ColumnsCategoriaType {
  id(title: 'ID'),
  nombre(title: 'Nombre'),
  estatus(title: 'Estatus'),
  diasEntrega(title: 'Días de Entrega'),
  fechaCreacion(title: 'Fecha de Creación'),
  fechaEliminacion(title: 'Fecha de Eliminación');

  final String title;

  const ColumnsCategoriaType({required this.title});
}
