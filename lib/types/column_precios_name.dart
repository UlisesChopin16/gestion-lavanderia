import 'package:gestion_lavanderia/types/sortable_column.dart';

export 'package:gestion_lavanderia/types/sortable_column.dart';

/// Columnas por las que puede ordenarse la lista de conceptos de precio.
enum ColumnPreciosName implements SortableColumn {
  id(title: 'ID'),
  nombre(title: 'Nombre del Concepto'),
  categoria(title: 'Categoría'),
  sizeRopa(title: 'Tamaño'),
  tipoUnidad(title: 'Unidad'),
  diasEntrega(title: 'Días de Entrega'),
  importe(title: '\$ Importe'),
  estatus(title: 'Estatus'),
  fechaCreacion(title: 'Fecha de Creación'),
  fechaEliminacion(title: 'Fecha de Eliminación');

  @override
  final String title;

  const ColumnPreciosName({required this.title});
}
