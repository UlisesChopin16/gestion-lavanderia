import 'package:gestion_lavanderia/types/sortable_column.dart';

export 'package:gestion_lavanderia/types/sortable_column.dart';

/// Columnas por las que puede ordenarse la lista de órdenes.
enum ColumnsOrdenesNames implements SortableColumn {
  id(title: '#'),
  folio(title: 'Folio'),
  cliente(title: 'Cliente'),
  estatus(title: 'Estatus'),
  total(title: 'Total'),
  restante(title: 'Restante'),
  metodoPago(title: 'Método de Pago'),
  fechaCreacion(title: 'Fecha de Creación'),
  ultimaInteraccion(title: 'Última interacción'),
  fechaCierre(title: 'Fecha de Cierre');

  @override
  final String title;

  const ColumnsOrdenesNames({required this.title});
}
