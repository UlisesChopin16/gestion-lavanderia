import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/view_model/catalogos_view_model.dart';

/// Las pestañas del módulo de catálogos, para el encabezado de cada listado.
///
/// Antes eran una `TabBar` con su propia franja encima de la tarjeta: un
/// renglón entero de alto para tres palabras, justo en una pantalla que no
/// tiene alto de sobra —encabezado, filtros, paginación y, por fin, la tabla—.
/// Puestas en el encabezado se aprovecha el renglón que ya estaba ahí: el
/// nombre del catálogo abierto lo dice ahora la pestaña marcada, que decía lo
/// mismo.
///
/// Lee la pestaña abierta del estado del módulo en lugar de llevar un
/// `TabController`: un catálogo puede mandar a otro —"ver los conceptos" de
/// una categoría abre los precios— y ese camino ya pasaba por aquí.
class PestanasCatalogo extends ConsumerWidget {
  const PestanasCatalogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abierta = ref.watch(
      catalogosViewModelProvider.select((estado) => estado.pestana),
    );
    final notifier = ref.read(catalogosViewModelProvider.notifier);

    // En una ventana angosta las pestañas bajan de renglón en lugar de
    // desbordarse: el encabezado las trata como un bloque más.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final pestana in CatalogosTabsType.values)
          _Pestana(
            pestana: pestana,
            seleccionada: pestana == abierta,
            onPressed: () => notifier.abrir(pestana),
          ),
      ],
    );
  }
}

/// Una pestaña: su icono y su nombre, marcada cuando es la que está abierta.
///
/// Se marca igual que un módulo en la barra de arriba —el mismo realce y el
/// mismo color—, para que no haya que aprender dos formas de ver dónde está
/// uno.
class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.pestana,
    required this.seleccionada,
    required this.onPressed,
  });

  final CatalogosTabsType pestana;
  final bool seleccionada;
  final VoidCallback onPressed;

  static final _radio = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = seleccionada ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada
            ? scheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: _radio,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  seleccionada ? pestana.icon : pestana.unselectedIcon,
                  size: 20,
                  color: color,
                ),
                Text(
                  pestana.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: seleccionada
                        ? FontWeight.w600
                        : FontWeight.w500,
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
