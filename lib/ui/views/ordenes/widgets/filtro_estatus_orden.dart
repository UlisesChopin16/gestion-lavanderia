import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/dropdown_menu_base.dart';

export 'package:gestion_lavanderia/types/estatus_orden_type.dart';

/// Acota el listado a las órdenes que están en un punto de su ciclo.
///
/// [EstatusOrdenType.todos] no se ofrece como opción: es no filtrar, y eso se
/// dice quitando la selección, igual que en los demás filtros. Con la opción
/// puesta, lo mismo se podía decir de dos maneras. Hacia afuera sigue siendo
/// `todos` lo que significa "sin filtro", porque es lo que el filtro guardado
/// y la consulta entienden.
class FiltroEstatusOrden extends StatelessWidget {
  const FiltroEstatusOrden({
    super.key,
    required this.estatus,
    required this.onChanged,
    this.width,
  });

  /// El estatus elegido, o [EstatusOrdenType.todos] cuando se ven todas.
  final EstatusOrdenType estatus;

  /// Recibe [EstatusOrdenType.todos] cuando se quita el filtro.
  final ValueChanged<EstatusOrdenType> onChanged;

  /// El ancho del desplegable. En `null` llena la columna que lo reciba.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final elegido = estatus == EstatusOrdenType.todos ? null : estatus;

    return DropdownMenuBase<EstatusOrdenType>(
      label: 'Estatus',
      width: width,
      value: elegido,
      showDelete: elegido != null,
      onDelete: () => onChanged(EstatusOrdenType.todos),
      leadingIcon: Icon(
        elegido?.icon ?? EstatusOrdenType.todos.icon,
        color: elegido?.color,
      ),
      items: [
        for (final opcion in EstatusOrdenType.values)
          if (opcion != EstatusOrdenType.todos)
            DropdownMenuEntry<EstatusOrdenType>(
              value: opcion,
              label: opcion.value,
              leadingIcon: Icon(opcion.icon, color: opcion.color),
            ),
      ],
      onChanged: (opcion) => onChanged(opcion ?? EstatusOrdenType.todos),
    );
  }
}
