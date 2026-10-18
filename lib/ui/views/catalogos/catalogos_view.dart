import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/view_model/catalogos_view_model.dart';

/// Los catálogos de la lavandería: clientes, categorías de ropa y precios.
///
/// El módulo es el listado abierto y nada más: las pestañas que eligen cuál
/// viven en el encabezado de cada uno —véase `PestanasCatalogo`— y no en una
/// franja propia, que se llevaba un renglón entero de alto encima de la
/// tarjeta.
///
/// Los listados ya visitados se quedan montados en el [IndexedStack] —como
/// hace el home con los módulos— para conservar la página y los filtros al ir
/// y volver, y los que no se han abierto no se construyen: cada uno consulta
/// la base al nacer, y abrir el módulo no tiene por qué lanzar tres consultas.
class CatalogosView extends ConsumerStatefulWidget {
  const CatalogosView({super.key});

  @override
  ConsumerState<CatalogosView> createState() => _CatalogosViewState();
}

class _CatalogosViewState extends ConsumerState<CatalogosView> {
  static const _pestanas = CatalogosTabsType.values;

  final _visitadas = <CatalogosTabsType>{};

  @override
  Widget build(BuildContext context) {
    final abierta = ref.watch(
      catalogosViewModelProvider.select((estado) => estado.pestana),
    );

    // Se anota aquí y no al cambiar de pestaña porque el cambio puede venir de
    // otro lado —"ver los conceptos" de una categoría abre los precios—, y
    // apuntar dos veces la misma pestaña no cambia nada.
    _visitadas.add(abierta);

    return IndexedStack(
      index: abierta.index,
      sizing: StackFit.expand,
      children: [
        for (final pestana in _pestanas)
          if (_visitadas.contains(pestana))
            pestana.view
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
