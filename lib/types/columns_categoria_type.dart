import 'package:gestion_lavanderia/types/sortable_column.dart';

export 'package:gestion_lavanderia/types/sortable_column.dart';

/// Columnas por las que puede ordenarse la lista de categorías.
enum ColumnsCategoriaType implements SortableColumn {
  id(title: 'ID'),
  nombre(title: 'Nombre'),
  estatus(title: 'Estatus'),
  diasEntrega(title: 'Días de Entrega'),
  fechaCreacion(title: 'Fecha de Creación'),
  fechaEliminacion(title: 'Fecha de Eliminación');

  @override
  final String title;

  const ColumnsCategoriaType({required this.title});
}
