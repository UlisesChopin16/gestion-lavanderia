import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/sortable_column.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/dropdown_menu_base.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Elige por qué columna se ordena un listado y en qué sentido.
///
/// Es genérico sobre el enum de columnas ([C]) porque antes había una copia de
/// este filtro por módulo —clientes, categorías, precios, órdenes—, idénticas
/// salvo el nombre del enum. Lo único que necesitan de la columna es su
/// [SortableColumn.title], que es justo lo que el contrato garantiza.
///
/// Cumple el mismo papel que pulsar un encabezado de la tabla, y existe porque
/// en la vista compacta no hay encabezados que pulsar.
class SortDropdown<C extends SortableColumn> extends StatelessWidget {
  const SortDropdown({
    super.key,
    required this.columns,
    required this.selected,
    required this.ascending,
    required this.onColumnChanged,
    required this.onAscendingChanged,
    this.label = 'Ordenar por',
    this.width = 220,
  });

  final List<C> columns;
  final C selected;
  final bool ascending;
  final ValueChanged<C> onColumnChanged;
  final ValueChanged<bool> onAscendingChanged;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<C>(
      label: label,
      width: width,
      value: selected,
      leadingIcon: _DirectionButton(
        ascending: ascending,
        onPressed: () => onAscendingChanged(!ascending),
      ),
      items: [
        for (final column in columns)
          DropdownMenuEntry<C>(value: column, label: column.title),
      ],
      // El desplegable sólo devuelve null si se vacía la selección, y aquí
      // siempre hay una columna ordenando: en ese caso se conserva la actual.
      onChanged: (column) => onColumnChanged(column ?? selected),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({required this.ascending, required this.onPressed});

  final bool ascending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      iconSize: 20,
      tooltip: ascending ? 'Ascendente' : 'Descendente',
      icon: Icon(IconsManager.getSortIcon(ascending)),
    );
  }
}
