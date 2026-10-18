import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/home/home_tabs_type.dart';

/// El menú lateral de módulos.
///
/// Cada módulo es un botón completo —icono arriba, nombre debajo, dentro de la
/// misma superficie—, y al seleccionarlo se ilumina entero. Antes era un
/// `NavigationRail`, que pinta el realce sólo alrededor del icono y deja el
/// nombre fuera: su indicador es de tamaño fijo y va apilado detrás del icono,
/// así que no hay forma de que cubra también el texto.
class MenuModulos extends StatelessWidget {
  const MenuModulos({
    super.key,
    required this.pestana,
    required this.onSeleccion,
    required this.botonTema,
  });

  final HomeTabsType pestana;
  final ValueChanged<HomeTabsType> onSeleccion;
  final Widget botonTema;

  /// Lo que mide el menú de ancho.
  ///
  /// Es angosto a propósito: con el nombre debajo del icono no necesita más, y
  /// cada píxel que no ocupa se lo queda el módulo abierto.
  static const ancho = 92.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Material(
      color: esOscuro ? theme.colorScheme.surface : Colors.white,
      elevation: 1,
      child: SizedBox(
        width: ancho,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              // Los módulos se desplazan si no caben; el botón del tema se
              // queda pegado abajo y no se va con ellos.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Column(
                    spacing: 4,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: botonTema,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un módulo del menú: su icono y, debajo, su nombre, dentro del mismo botón.
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

  static final _radio = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = seleccionado ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: seleccionado,
      child: Material(
        // El realce del módulo abierto cubre el botón entero, nombre incluido.
        color: seleccionado
            ? scheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: _radio,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  seleccionado ? tab.icon : tab.unselectedIcon,
                  color: color,
                ),
                Text(
                  tab.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // Un cuerpo menor que el de las etiquetas normales: el nombre
                  // tiene que caber en el ancho del menú sin partirse.
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: seleccionado
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
