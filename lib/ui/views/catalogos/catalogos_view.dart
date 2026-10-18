import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/view_model/catalogos_view_model.dart';

/// Los catálogos de la lavandería: clientes, categorías de ropa y precios.
///
/// La barra elige el catálogo y debajo va el listado, que se queda con todo el
/// espacio restante.
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

class _CatalogosViewState extends ConsumerState<CatalogosView>
    with SingleTickerProviderStateMixin {
  static const _pestanas = CatalogosTabsType.values;

  late CatalogosTabsType _pestana;
  late final TabController _controlador;
  final _visitadas = <CatalogosTabsType>{};

  @override
  void initState() {
    super.initState();

    _pestana = ref.read(catalogosViewModelProvider).pestana;
    _visitadas.add(_pestana);

    _controlador = TabController(
      length: _pestanas.length,
      initialIndex: _pestana.index,
      vsync: this,
    )..addListener(_alCambiarPestana);
  }

  @override
  void dispose() {
    _controlador
      ..removeListener(_alCambiarPestana)
      ..dispose();
    super.dispose();
  }

  /// El controlador avisa varias veces por cada cambio —una al tocar y otras
  /// tantas mientras la barra se desliza—, así que sólo se atiende cuando la
  /// pestaña de verdad cambió.
  void _alCambiarPestana() {
    final pestana = _pestanas[_controlador.index];
    if (pestana == _pestana) return;

    setState(() {
      _pestana = pestana;
      _visitadas.add(pestana);
    });

    ref.read(catalogosViewModelProvider.notifier).abrir(pestana);
  }

  @override
  Widget build(BuildContext context) {
    // Un catálogo puede mandar a otro: "ver conceptos" de una categoría abre
    // los precios ya filtrados. Se escucha el cambio y se mueve el
    // controlador, que es quien manda sobre la barra.
    ref.listen(catalogosViewModelProvider.select((estado) => estado.pestana), (
      _,
      pestana,
    ) {
      if (_controlador.index != pestana.index) {
        _controlador.animateTo(pestana.index);
      }
    });

    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _controlador,
            tabs: [
              for (final pestana in _pestanas)
                Tab(
                  icon: Icon(
                    pestana == _pestana ? pestana.icon : pestana.unselectedIcon,
                  ),
                  text: pestana.title,
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: IndexedStack(
            index: _pestana.index,
            sizing: StackFit.expand,
            children: [
              for (final pestana in _pestanas)
                if (_visitadas.contains(pestana))
                  pestana.view
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
