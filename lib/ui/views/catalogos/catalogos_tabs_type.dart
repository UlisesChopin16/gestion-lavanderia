import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/categorias_view.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/clientes_view.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/precios_view.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Los catálogos del módulo, en el orden en que aparecen en la barra.
///
/// Cada entrada trae su listado, igual que `HomeTabsType` trae sus módulos:
/// agregar un catálogo es agregar una constante.
///
/// El orden no es casual: los clientes son el catálogo que más se consulta, y
/// las categorías van antes que los precios porque un concepto necesita una
/// categoría donde vivir.
enum CatalogosTabsType {
  clientes(
    title: 'Clientes',
    icon: IconsManager.selectedClientesIcon,
    unselectedIcon: IconsManager.unselectedClientesIcon,
    view: ClientesView(),
  ),
  categorias(
    title: 'Categorías de ropa',
    icon: IconsManager.selectedCategoriasIcon,
    unselectedIcon: IconsManager.unselectedCategoriasIcon,
    view: CategoriasView(),
  ),
  precios(
    title: 'Precios de ropa',
    icon: IconsManager.selectedPreciosIcon,
    unselectedIcon: IconsManager.unselectedPreciosIcon,
    view: PreciosView(),
  );

  const CatalogosTabsType({
    required this.title,
    required this.icon,
    required this.unselectedIcon,
    required this.view,
  });

  final String title;
  final IconData icon;
  final IconData unselectedIcon;
  final Widget view;
}
