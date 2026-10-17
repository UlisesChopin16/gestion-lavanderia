import 'package:gestion_lavanderia/types/sortable_column.dart';

export 'package:gestion_lavanderia/types/sortable_column.dart';

/// Columnas por las que puede ordenarse la lista de clientes.
enum ColumnClientesName implements SortableColumn {
  id(title: 'ID'),
  nombre(title: 'Nombre(s)'),
  apellido(title: 'Apellido(s)'),
  telefono(title: 'Teléfono'),
  correo(title: 'Correo'),
  fechaCreacion(title: 'Fecha de Creación');

  @override
  final String title;

  const ColumnClientesName({required this.title});
}
