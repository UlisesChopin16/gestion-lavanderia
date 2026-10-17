import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/delete_button.dart';

/// Desplegable que marca la opción elegida.
///
/// Administra su propio `TextEditingController` y lo sincroniza cuando [value]
/// cambia desde fuera. Antes el controlador lo creaba cada filtro con un hook
/// y le escribía el texto dentro de `build`: escribir en un controlador
/// durante la construcción reinicia la selección del campo y vuelve a
/// notificar a sus escuchas en medio del dibujado.
class DropdownMenuBase<T> extends StatefulWidget {
  const DropdownMenuBase({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.leadingIcon,
    this.showDelete = false,
    this.onDelete,
    this.enableSearch = false,
    this.width,
  });

  final List<DropdownMenuEntry<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? label;
  final Widget? leadingIcon;

  /// Reemplaza el icono inicial por un botón que limpia la selección.
  final bool showDelete;
  final VoidCallback? onDelete;

  final bool enableSearch;
  final double? width;

  @override
  State<DropdownMenuBase<T>> createState() => _DropdownMenuBaseState<T>();
}

class _DropdownMenuBaseState<T> extends State<DropdownMenuBase<T>> {
  late final TextEditingController _controller = TextEditingController(
    text: _labelForValue,
  );

  /// El texto de la opción elegida, o vacío si no hay ninguna.
  String get _labelForValue {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return '';
  }

  @override
  void didUpdateWidget(DropdownMenuBase<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La selección puede cambiar sin pasar por el desplegable: al limpiar los
    // filtros, por ejemplo. El texto se repone sólo si quedó desfasado, para
    // no mover el cursor mientras el usuario escribe en la búsqueda.
    final label = _labelForValue;
    if (_controller.text != label) _controller.text = label;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget? get _leading {
    if (widget.showDelete) return DeleteButton(onPressed: widget.onDelete);
    return widget.leadingIcon;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      width: widget.width,
      enableSearch: widget.enableSearch,
      requestFocusOnTap: widget.enableSearch,
      controller: _controller,
      initialSelection: widget.value,
      leadingIcon: _leading,
      label: widget.label == null ? null : Text(widget.label!),
      onSelected: widget.onChanged,
      dropdownMenuEntries: _entries(context),
    );
  }

  /// Las opciones, con la elegida resaltada y con una marca al final.
  List<DropdownMenuEntry<T>> _entries(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return widget.items.map((item) {
      final isSelected = item.value == widget.value;

      return DropdownMenuEntry<T>(
        value: item.value,
        label: item.label,
        enabled: item.enabled,
        labelWidget: item.labelWidget,
        leadingIcon: item.leadingIcon,
        trailingIcon: isSelected ? const Icon(Icons.check_rounded) : null,
        style: isSelected
            ? MenuItemButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              )
            : null,
      );
    }).toList();
  }
}
