/// Columnas por las que puede ordenarse la lista de órdenes.
enum ColumnsOrdenesNames {
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

  final String title;

  const ColumnsOrdenesNames({required this.title});
}
