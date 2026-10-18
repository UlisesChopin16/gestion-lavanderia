import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/dropdown_menu_base.dart';

export 'package:gestion_lavanderia/types/estatus_type.dart';

/// Acota un listado a los registros activos o a los dados de baja.
///
/// Es un desplegable como los demás filtros —antes era un grupo de segmentos—
/// para que el renglón de filtros se lea como una sola fila de controles
/// iguales en lugar de uno distinto por filtro.
///
/// No tiene opción de "todos": eso es no filtrar, y se consigue quitando la
/// selección con el botón que aparece en su lugar. Con la opción puesta, lo
/// mismo se podía decir de dos maneras.
class EstatusFilter extends StatelessWidget {
  const EstatusFilter({
    super.key,
    required this.estatus,
    required this.onChanged,
    this.label = 'Estatus',
    this.width,
  });

  /// El estatus elegido, o `null` cuando se ven todos.
  final EstatusType? estatus;

  /// Recibe `null` cuando se quita el filtro.
  final ValueChanged<EstatusType?> onChanged;

  final String label;

  /// El ancho del desplegable. En `null` llena la columna que lo reciba, que
  /// es lo que hace falta en un renglón de filtros: con un ancho fijo, el
  /// filtro se quedaba apretado y dejaba el hueco de al lado vacío.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<EstatusType>(
      label: label,
      width: width,
      showDelete: estatus != null,
      onDelete: () => onChanged(null),
      leadingIcon: const Icon(Icons.toggle_on_rounded),
      value: estatus,
      items: [
        for (final opcion in EstatusType.values)
          DropdownMenuEntry<EstatusType>(value: opcion, label: opcion.value),
      ],
      onChanged: onChanged,
    );
  }
}
