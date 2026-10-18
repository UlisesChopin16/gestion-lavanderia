import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/clothe_size_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

export 'package:gestion_lavanderia/types/clothe_size_type.dart';

/// El tamaño de la ropa de un concepto.
///
/// Sirve de filtro y de campo del formulario, que es la diferencia que marca
/// [permiteQuitar]: como filtro, "sin elegir" significa todos los tamaños y
/// por eso se puede borrar la selección; en el formulario siempre hay uno,
/// porque "sin tamaño" es a su vez una opción del catálogo.
class SelectorTamano extends StatelessWidget {
  const SelectorTamano({
    super.key,
    required this.tamano,
    required this.onChanged,
    this.label = 'Tamaño',
    this.permiteQuitar = false,
    this.onQuitar,
    this.width,
  });

  final ClotheSizeType? tamano;
  final ValueChanged<ClotheSizeType?> onChanged;
  final String label;
  final bool permiteQuitar;
  final VoidCallback? onQuitar;

  /// El ancho del desplegable. En `null` llena el hueco que recibe: como
  /// filtro eso es su columna de la rejilla, y en el formulario se le pasa el
  /// ancho de los demás campos para que todos midan igual.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<ClotheSizeType>(
      label: label,
      width: width,
      showDelete: permiteQuitar && tamano != null,
      onDelete: onQuitar,
      leadingIcon: const Icon(IconsManager.clotheIcon),
      value: tamano,
      items: [
        for (final opcion in ClotheSizeType.values)
          DropdownMenuEntry<ClotheSizeType>(
            value: opcion,
            label: opcion.description,
          ),
      ],
      onChanged: onChanged,
    );
  }
}
