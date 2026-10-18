/// Visibilidad de un registro con baja lógica.
///
/// No hay una constante para "todos": que un listado no filtre por estatus se
/// dice con un `null` en sus filtros. Así la ausencia de filtro no se puede
/// confundir con un estatus, ni acabar escrita en la base como uno más.
enum EstatusType {
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
