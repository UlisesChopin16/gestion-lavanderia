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

  /// Las opciones ya armadas, con la elegida resaltada.
  ///
  /// Se guardan en lugar de rehacerlas en cada `build` porque `DropdownMenu`
  /// compara la lista por identidad: una lista nueva —aunque diga exactamente
  /// lo mismo— le hace generar una `GlobalKey` por opción y olvidar cuál venía
  /// resaltada con las flechas del teclado. Y el padre se reconstruye por
  /// cualquier cosa: basta teclear en el filtro de al lado.
  late List<DropdownMenuEntry<T>> _entries;

  /// El texto de la opción elegida, o vacío si no hay ninguna.
  String get _labelForValue {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }

    return '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El color de la opción elegida sale del tema, así que las opciones se
    // rehacen también cuando el tema cambia.
    _entries = _construirEntries();
  }

  @override
  void didUpdateWidget(DropdownMenuBase<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != oldWidget.value || _cambiaron(oldWidget.items)) {
      _entries = _construirEntries();
    }

    // La selección puede cambiar sin pasar por el desplegable: al limpiar los
    // filtros, por ejemplo. El texto se repone sólo si quedó desfasado, para
    // no mover el cursor mientras el usuario escribe en la búsqueda.
    //
    // `DropdownMenu` repone el suyo cuando cambia `initialSelection`, pero
    // sólo si la opción existe: al quitar la selección se quedaría con el
    // nombre de la anterior escrito. Vaciarlo es cosa de aquí.
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
    if (width != null) return _menu(width);

    // `DropdownMenu` se mide por su opción más larga y se queda de ese ancho
    // aunque le sobre sitio: no hay forma de decirle "llena lo que te den"
    // más que pasándole el ancho ya medido. Por eso el hueco se mide aquí y
    // se le entrega hecho un número.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _menu(constraints.hasBoundedWidth ? constraints.maxWidth : null),
    );
  }

  Widget _menu(double? width) {
    final label = widget.label;

    return DropdownMenu<T>(
      width: width,
      enableSearch: widget.enableSearch,
      requestFocusOnTap: widget.enableSearch,
      controller: _controller,
      initialSelection: widget.value,
      leadingIcon: _leading,
      label: label == null ? null : Text(label),
      onSelected: widget.onChanged,
      dropdownMenuEntries: _entries,
    );
  }

  /// Si las opciones dicen algo distinto de las que ya están armadas.
  ///
  /// `DropdownMenuEntry` no se compara por valor, y la pantalla arma una lista
  /// nueva en cada reconstrucción, así que compararla por identidad sería
  /// decir "cambió" siempre. Se miran en su lugar el valor, el nombre y si
  /// está habilitada, que es lo que distingue una opción de otra; recorrer
  /// unas cuantas cuesta menos que rehacerlas todas.
  ///
  /// Los widgets de cada opción —su icono— quedan fuera de la comparación
  /// porque se construyen de nuevo cada vez y nunca serían iguales. Da lo
  /// mismo mientras el icono dependa del valor de la opción, que es como lo
  /// usan los filtros: el mismo método de pago siempre trae el mismo icono.
  bool _cambiaron(List<DropdownMenuEntry<T>> anteriores) {
    if (anteriores.length != widget.items.length) return true;

    for (var i = 0; i < anteriores.length; i++) {
      final antes = anteriores[i];
      final ahora = widget.items[i];

      if (antes.value != ahora.value ||
          antes.label != ahora.label ||
          antes.enabled != ahora.enabled) {
        return true;
      }
    }

    return false;
  }

  /// Las opciones, con la elegida resaltada y con una marca al final.
  List<DropdownMenuEntry<T>> _construirEntries() {
    final scheme = Theme.of(context).colorScheme;

    // El estilo de la elegida se arma una sola vez: sólo hay una, pero así
    // tampoco se rehace por cada opción que se descarta.
    //
    // `iconColor` va aparte de `foregroundColor` a propósito: `MenuItemButton`
    // trae un color de icono propio —`onSurfaceVariant`— que gana sobre el
    // color de primer plano, así que sin esta línea el icono de la opción
    // elegida y su palomita se quedaban grises sobre el fondo primario.
    final elegida = MenuItemButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      iconColor: scheme.onPrimary,
    );

    return [
      for (final item in widget.items)
        if (item.value == widget.value)
          DropdownMenuEntry<T>(
            value: item.value,
            label: item.label,
            enabled: item.enabled,
            labelWidget: item.labelWidget,
            leadingIcon: item.leadingIcon,
            trailingIcon: const Icon(Icons.check_rounded),
            style: elegida,
          )
        else
          item,
    ];
  }
}
