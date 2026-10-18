import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/views/pantalla_pendiente.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/catalogos_view.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/configuracion_empresa_view.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Los módulos de la aplicación, en el orden en que aparecen en la navegación.
///
/// Cada entrada trae su pantalla, así que agregar un módulo es agregar una
/// constante: el home no tiene que saber cuáles existen ni en qué orden van.
///
/// Vive junto al home y no en `lib/types/` —donde estaba antes— porque
/// referencia pantallas: un archivo de tipos que importa vistas invierte la
/// dependencia, y al final la lista sólo le sirve a quien dibuja la navegación.
enum HomeTabsType {
  ordenes(
    title: 'Órdenes',
    icon: IconsManager.selectedOrdenServicioIcon,
    unselectedIcon: IconsManager.unselectedOrdenServicioIcon,
    view: PantallaPendiente(modulo: 'Órdenes de servicio'),
  ),
  catalogos(
    title: 'Catálogos',
    icon: IconsManager.selectedCatalogoIcon,
    unselectedIcon: IconsManager.unselectedCatalogoIcon,
    view: CatalogosView(),
  ),
  empresa(
    title: 'Empresa',
    icon: IconsManager.selectedEmpresaIcon,
    unselectedIcon: IconsManager.unselectedEmpresaIcon,
    view: ConfiguracionEmpresaView(),
  );

  const HomeTabsType({
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
