import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Acota la lista de conceptos a una categoría.
///
/// Ofrece también las categorías dadas de baja: es la forma de ver qué
/// conceptos se fueron con una de ellas.
class FiltroCategoria extends StatelessWidget {
  const FiltroCategoria({
    super.key,
    required this.categorias,
    required this.seleccionada,
    required this.onChanged,
    required this.onQuitar,
  });

  final Iterable<CategoriaServicioEntry> categorias;

  /// La categoría elegida, o [sinCategoria] cuando están todas.
  final int seleccionada;

  final ValueChanged<int> onChanged;
  final VoidCallback onQuitar;

  static const _ancho = 220.0;

  bool get _hayFiltro => seleccionada != sinCategoria;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<int>(
      label: 'Categoría',
      width: _ancho,
      // Sin categoría elegida no hay nada que quitar, así que en su lugar va
      // el icono del catálogo.
      showDelete: _hayFiltro,
      onDelete: onQuitar,
      leadingIcon: const Icon(IconsManager.selectedCategoriasIcon),
      value: _hayFiltro ? seleccionada : null,
      items: [
        for (final categoria in categorias)
          DropdownMenuEntry<int>(
            value: categoria.id,
            label: categoria.estatus == EstatusType.activo
                ? categoria.nombre
                : '${categoria.nombre} (inactiva)',
          ),
      ],
      onChanged: (id) => onChanged(id ?? sinCategoria),
    );
  }
}
