/// Visibilidad de un registro con baja lógica.
///
/// `todos` no se guarda nunca en la base: existe sólo como opción de filtro.
enum EstatusType {
  todos(value: 'Todos'),
  activo(value: 'Activo'),
  inactivo(value: 'Inactivo');

  final String value;

  const EstatusType({required this.value});

  factory EstatusType.fromString(String value) {
    return EstatusType.values.firstWhere(
      (estatus) => estatus.value == value,
      orElse: () => EstatusType.inactivo,
    );
  }
}
