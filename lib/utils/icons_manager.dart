import 'package:flutter/material.dart';

/// Los iconos de la aplicación, en un solo lugar.
///
/// Cada sección tiene el par seleccionado/sin seleccionar que piden las barras
/// de navegación; nombrarlos aquí evita que la misma sección aparezca con un
/// icono distinto en el menú y en su pantalla.
abstract final class IconsManager {
  // Empresa
  static const selectedEmpresaIcon = Icons.business_rounded;
  static const unselectedEmpresaIcon = Icons.business_outlined;

  // Órdenes de servicio
  static const selectedOrdenServicioIcon = Icons.receipt_long;
  static const unselectedOrdenServicioIcon = Icons.receipt_long_outlined;

  // Catálogos
  static const selectedCatalogoIcon = Icons.menu_book_rounded;
  static const unselectedCatalogoIcon = Icons.menu_book_outlined;

  // Clientes
  static const selectedClientesIcon = Icons.people_rounded;
  static const unselectedClientesIcon = Icons.people_outlined;

  // Categorías
  static const selectedCategoriasIcon = Icons.category_rounded;
  static const unselectedCategoriasIcon = Icons.category_outlined;

  // Tamaños de ropa
  static const selectedSizesIcon = Icons.design_services_rounded;
  static const unselectedSizesIcon = Icons.design_services_outlined;

  // Precios
  static const selectedPreciosIcon = Icons.paid_rounded;
  static const unselectedPreciosIcon = Icons.paid_outlined;

  static const orderAZ = Icons.arrow_upward;
  static const orderZA = Icons.arrow_downward;

  static const clotheIcon = Icons.checkroom_rounded;

  static const calendar = Icons.calendar_month;
  static const calendarRange = Icons.date_range;

  static const actionsMenu = Icons.more_vert;
  static const search = Icons.search;
  static const add = Icons.add;
  static const clearFilters = Icons.clear_rounded;

  static IconData getSortIcon(bool isAscending) =>
      isAscending ? orderAZ : orderZA;
}
