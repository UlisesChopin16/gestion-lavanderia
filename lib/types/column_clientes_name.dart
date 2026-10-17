/// Columnas por las que puede ordenarse la lista de clientes.
enum ColumnClientesName {
  id(title: 'ID'),
  nombre(title: 'Nombre(s)'),
  apellido(title: 'Apellido(s)'),
  telefono(title: 'Teléfono'),
  correo(title: 'Correo'),
  fechaCreacion(title: 'Fecha de Creación');

  final String title;

  const ColumnClientesName({required this.title});
}
