import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/home/home_tabs_type.dart';

/// Los módulos de la aplicación, en una barra arriba de todo.
///
/// Antes era un riel pegado a la izquierda. Se subió aquí porque en esta
/// aplicación el ancho vale más que el alto: las pantallas son listados con
/// tablas que se desbordan a lo ancho, y el riel les quitaba noventa y dos
/// píxeles de cada una para decir tres palabras que caben de sobra en un
/// renglón.
///
/// Los módulos van sin icono: con tres nombres cortos, el icono no distinguía
/// nada que el nombre no dijera ya, y en una barra horizontal obligaba a
/// hacerla el doble de alta.
///
/// El módulo abierto se queda marcado, que es lo que dice dónde está uno
/// cuando ya no hay riel que lo señale.
class BarraModulos extends StatelessWidget implements PreferredSizeWidget {
  const BarraModulos({
    super.key,
    required this.pestana,
    required this.onSeleccion,
    required this.botonTema,
  });

  final HomeTabsType pestana;
  final ValueChanged<HomeTabsType> onSeleccion;

  /// El botón que cambia el tema. Lo arma el home —es suyo el estado— y la
  /// barra sólo le da sitio, al otro extremo de los módulos.
  final Widget botonTema;

  /// Lo que mide la barra de alto.
  static const alto = 60.0;

  @override
  Size get preferredSize => const Size.fromHeight(alto);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final esOscuro = theme.brightness == Brightness.dark;

    return AppBar(
      toolbarHeight: alto,
      elevation: 1,
      // No va en el color primario como las demás barras de la aplicación: el
      // módulo abierto se marca con ese mismo color, y sobre un fondo primario
      // no se distinguiría de los otros dos.
      backgroundColor: esOscuro ? scheme.surface : Colors.white,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      titleSpacing: 12,
      // Los módulos se desplazan a lo ancho si algún día son más de los que
      // caben, en lugar de desbordarse.
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 8,
          children: [
            for (final tab in HomeTabsType.values)
              BotonModulo(
                tab: tab,
                seleccionado: tab == pestana,
                onPressed: () => onSeleccion(tab),
              ),
          ],
        ),
      ),
      actions: [botonTema, const SizedBox(width: 8)],
    );
  }
}

/// Un módulo de la barra: su nombre, realzado cuando es el que está abierto.
class BotonModulo extends StatelessWidget {
  const BotonModulo({
    super.key,
    required this.tab,
    required this.seleccionado,
    required this.onPressed,
  });

  final HomeTabsType tab;
  final bool seleccionado;
  final VoidCallback onPressed;

  static final _radio = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = seleccionado ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: seleccionado,
      child: Material(
        // El realce cubre el botón entero y no sólo el texto: es lo que se ve
        // de lejos al buscar en qué módulo está uno.
        color: seleccionado
            ? scheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: _radio,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              tab.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
