import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

export 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

/// Qué filas se están viendo y cómo pasar de página.
///
/// Va entre los filtros y la lista, no al pie: ahí está siempre a la vista y
/// junto a los controles con los que se usa, en lugar de al final de una lista
/// que hay que recorrer entera para llegar a él.
///
/// A la izquierda, cuántas filas se ven de cuántas; a la derecha, el tamaño de
/// página y las flechas. En una ventana angosta el renglón se parte en dos en
/// vez de desbordarse.
///
/// No decide nada: recibe la [Paginacion] del listado y avisa de lo que se
/// pidió. El recorte de las filas lo hace el modelo de la pantalla, que es
/// quien tiene la lista completa.
class TablePagination extends StatelessWidget {
  const TablePagination({
    super.key,
    required this.paginacion,
    required this.onPaginaChanged,
    this.onPorPaginaChanged,
    this.etiquetaFilas = 'Filas',
  });

  final Paginacion paginacion;
  final ValueChanged<int> onPaginaChanged;

  /// En `null` el tamaño de página no se puede cambiar y el selector no
  /// aparece.
  final ValueChanged<int>? onPorPaginaChanged;

  final String etiquetaFilas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPorPaginaChanged = this.onPorPaginaChanged;

    return Wrap(
      // Con sitio de sobra, el resumen se va a la izquierda y los controles a
      // la derecha; cuando no lo hay, se apilan.
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Text(
          _resumen,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            if (onPorPaginaChanged != null)
              _SelectorPorPagina(
                porPagina: paginacion.porPagina,
                etiqueta: etiquetaFilas,
                onChanged: onPorPaginaChanged,
              ),
            _Navegacion(
              paginacion: paginacion,
              onPaginaChanged: onPaginaChanged,
            ),
          ],
        ),
      ],
    );
  }

  /// Qué filas se están viendo, de cuántas.
  String get _resumen {
    if (paginacion.total == 0) return 'Sin resultados';

    return 'Mostrando ${paginacion.desde}-${paginacion.hasta} '
        'de ${paginacion.total}';
  }
}

/// Las flechas y la página actual, agrupadas en un solo control.
///
/// Con sitio de sobra lleva las cuatro flechas y la página escrita completa;
/// cuando el ancho no da, se queda con ir atrás y adelante y con "1 de 4". El
/// recorte se decide con el ancho que recibe de verdad y no con el de la
/// ventana: la paginación puede vivir dentro de un panel angosto.
class _Navegacion extends StatelessWidget {
  const _Navegacion({required this.paginacion, required this.onPaginaChanged});

  final Paginacion paginacion;
  final ValueChanged<int> onPaginaChanged;

  /// Lo que mide el control con todo puesto. Por debajo de esto, las flechas
  /// de primera y última página se van.
  static const double _anchoCompleto = 380;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final completo = constraints.maxWidth >= _anchoCompleto;

        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (completo)
                _Flecha(
                  tooltip: 'Primera página',
                  icono: Icons.first_page_rounded,
                  onPressed: paginacion.hayAnterior
                      ? () => onPaginaChanged(1)
                      : null,
                ),
              _Flecha(
                tooltip: 'Página anterior',
                icono: Icons.chevron_left_rounded,
                onPressed: paginacion.hayAnterior
                    ? () => onPaginaChanged(paginacion.pagina - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Tooltip(
                  message:
                      'Página ${paginacion.pagina} de ${paginacion.paginas}',
                  child: Text(
                    completo
                        ? 'Página ${paginacion.pagina} de ${paginacion.paginas}'
                        : '${paginacion.pagina} de ${paginacion.paginas}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _Flecha(
                tooltip: 'Página siguiente',
                icono: Icons.chevron_right_rounded,
                onPressed: paginacion.haySiguiente
                    ? () => onPaginaChanged(paginacion.pagina + 1)
                    : null,
              ),
              if (completo)
                _Flecha(
                  tooltip: 'Última página',
                  icono: Icons.last_page_rounded,
                  onPressed: paginacion.haySiguiente
                      ? () => onPaginaChanged(paginacion.paginas)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Una flecha de la navegación, apagada cuando no hay a dónde ir.
class _Flecha extends StatelessWidget {
  const _Flecha({
    required this.tooltip,
    required this.icono,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icono),
      onPressed: onPressed,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Cuántas filas se muestran por página.
///
/// Es un `DropdownButton` y no el desplegable con campo de texto de los
/// filtros: son cuatro números fijos, y un campo escribible invitaría a teclear
/// un tamaño que la lista no ofrece.
class _SelectorPorPagina extends StatelessWidget {
  const _SelectorPorPagina({
    required this.porPagina,
    required this.etiqueta,
    required this.onChanged,
  });

  final int porPagina;
  final String etiqueta;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Text(
          etiqueta,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: DropdownButton<int>(
            value: porPagina,
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (valor) => onChanged(valor ?? porPagina),
            items: [
              for (final opcion in Paginacion.opciones)
                DropdownMenuItem(value: opcion, child: Text('$opcion')),
            ],
          ),
        ),
      ],
    );
  }
}
