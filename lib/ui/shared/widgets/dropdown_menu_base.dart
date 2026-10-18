import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/delete_button.dart';

/// Desplegable que marca la opción elegida.
///
/// Administra su propio `TextEditingController` y lo sincroniza cuando [value]
/// cambia desde fuera. Antes el controlador lo creaba cada filtro con un hook
/// y le escribía el texto dentro de `build`: escribir en un controlador
/// durante la construcción reinicia la selección del campo y vuelve a
/// notificar a sus escuchas en medio del dibujado.
///
/// Sin [width] ocupa todo el hueco que le den. Eso lo mide un `LayoutBuilder`,
/// así que no sabe decir cuánto mediría por su cuenta: dentro de una rejilla
/// no se le puede poner en una columna `VCol.auto`, que es justo la que
/// pregunta eso.
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

  /// Lo que un desplegable necesita para que se lea la opción elegida.
  ///
  /// Las pantallas se lo pasan como `minWidth` a la columna que lo lleva: por
  /// debajo de eso, el renglón de filtros se parte antes que aplastarlo.
  static const double anchoMinimo = 200;

  /// Lo que no pasa aunque le sobre sitio.
  ///
  /// Un desplegable que se queda solo en el último renglón se llevaría todo el
  /// ancho de la tarjeta, y uno de media pantalla no parece un desplegable.
  /// Está por encima de lo que mide una tarjeta en una ventana angosta, donde
  /// el filtro sí ocupa el renglón entero junto a los demás.
  static const double anchoMaximo = 460;

  final List<DropdownMenuEntry<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? label;
  final Widget? leadingIcon;

  /// Reemplaza el icono inicial por un botón que limpia la selección.
  final bool showDelete;
  final VoidCallback? onDelete;

  final bool enableSearch;

  /// El ancho del control. En `null` llena el hueco que recibe.
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
    final width = widget.width;
    if (width != null) return _menu(context, width);

    // `DropdownMenu` se mide por su opción más larga y se queda de ese ancho
    // aunque le sobre sitio: no hay forma de decirle "llena lo que te den"
    // más que pasándole el ancho ya medido. Por eso el hueco se mide aquí y
    // se le entrega hecho un número.
    return LayoutBuilder(
      builder: (context, constraints) => _menu(
        context,
        constraints.hasBoundedWidth ? constraints.maxWidth : null,
      ),
    );
  }

  Widget _menu(BuildContext context, double? width) {
    return DropdownMenu<T>(
      width: width,
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
