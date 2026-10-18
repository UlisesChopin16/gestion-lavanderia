import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/home/view_model/home_view_model.dart';
import 'package:gestion_lavanderia/ui/views/home/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// La pantalla principal: la navegación entre módulos y el módulo abierto.
///
/// El módulo ocupa todo el espacio que deja la navegación, que va arriba y no
/// al costado: las pantallas son listados anchos y un menú lateral les quitaba
/// el espacio que más falta les hace.
///
/// La navegación cambia de forma con el ancho de la ventana —es una aplicación
/// de escritorio, y se puede dejar en media pantalla—:
///
/// - angosta: una barra con el nombre del módulo y el cajón detrás del botón,
///   que sólo ocupa espacio mientras está abierto;
/// - a partir de ahí: la barra de módulos, con los tres a la vista.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  /// Mantiene vivo el contenido cuando la ventana cruza un corte y la
  /// navegación cambia de forma: sin la llave, mudar el contenido de un `Row` a
  /// un `body` lo construiría de nuevo y se perdería lo que llevara abierto.
  final _contenido = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(homeViewModelProvider.notifier);
    final (pestana, themeMode) = ref.watch(
      homeViewModelProvider.select(
        (estado) => (estado.pestana, estado.themeMode),
      ),
    );

    final contenido = _Contenido(key: _contenido, pestana: pestana);
    final botonTema = BotonTema(
      themeMode: themeMode,
      onPressed: notifier.cambiarTema,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ConstantsManager.smallScreen) {
          return Scaffold(
            appBar: AppBar(
              // El nombre del módulo abierto: sin menú a la vista, es lo único
              // que dice dónde está uno.
              title: Text(pestana.title),
              actions: [botonTema],
            ),
            drawer: DrawerModulos(
              pestana: pestana,
              onSeleccion: notifier.seleccionarPestana,
            ),
            body: contenido,
          );
        }

        return Scaffold(
          appBar: BarraModulos(
            pestana: pestana,
            onSeleccion: notifier.seleccionarPestana,
            botonTema: botonTema,
          ),
          // El módulo se queda con el ancho entero de la ventana.
          body: contenido,
        );
      },
    );
  }
}

/// El módulo abierto, ocupando todo el espacio que recibe.
///
/// Los módulos que ya se visitaron se quedan montados en el [IndexedStack]: al
/// volver a uno siguen ahí su captura a medias, sus filtros y su posición de
/// desplazamiento. Los que no se han abierto todavía no se construyen —un
/// `IndexedStack` normal construye todos al arrancar, y cada listado abriría su
/// consulta a la base sin que nadie la haya pedido—.
class _Contenido extends StatefulWidget {
  const _Contenido({super.key, required this.pestana});

  final HomeTabsType pestana;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  final _visitadas = <HomeTabsType>{};

  @override
  void initState() {
    super.initState();
    _visitadas.add(widget.pestana);
  }

  @override
  void didUpdateWidget(_Contenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No hace falta `setState`: después de `didUpdateWidget` viene `build`.
    _visitadas.add(widget.pestana);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.pestana.index,
      sizing: StackFit.expand,
      children: [
        for (final pestana in HomeTabsType.values)
          if (_visitadas.contains(pestana))
            pestana.view
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
