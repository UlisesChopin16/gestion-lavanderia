import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/home/home_tabs_type.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// Los módulos en un cajón lateral, para las ventanas angostas.
///
/// Ahí el menú fijo se comería el poco ancho que queda, así que se esconde
/// detrás del botón de la barra superior y sólo aparece cuando se pide.
///
/// Los módulos van en renglones con el icono a la izquierda, y no apilados como
/// en el menú fijo: el cajón es ancho, y amontonar el texto bajo el icono
/// dejaría media pantalla vacía.
class DrawerModulos extends StatelessWidget {
  const DrawerModulos({
    super.key,
    required this.pestana,
    required this.onSeleccion,
  });

  final HomeTabsType pestana;
  final ValueChanged<HomeTabsType> onSeleccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                ConstantsManager.appName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                children: [
                  for (final tab in HomeTabsType.values)
                    ListTile(
                      leading: Icon(
                        tab == pestana ? tab.icon : tab.unselectedIcon,
                      ),
                      title: Text(tab.title),
                      selected: tab == pestana,
                      selectedColor: scheme.primary,
                      selectedTileColor: scheme.primary.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onTap: () {
                        onSeleccion(tab);
                        // El cajón se cierra solo: dejarlo abierto taparía el
                        // módulo que se acaba de abrir.
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
