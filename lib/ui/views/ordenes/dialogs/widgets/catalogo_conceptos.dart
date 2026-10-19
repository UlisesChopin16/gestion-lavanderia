import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/widgets/paso_titulo.dart';

/// El catálogo del que se eligen las prendas de la orden.
///
/// Un toque en el renglón agrega una unidad, y tocarlo otra vez agrega otra:
/// no hay que abrir nada ni escribir una cantidad para el caso normal, que es
/// una o dos prendas de cada concepto. Lo que ya lleva la orden se marca con
/// su cantidad en el propio renglón, para no tener que mirar a la otra
/// columna para saber si ya se agregó.
///
/// Cada renglón dice lo que hace falta para elegir: cómo se llama, de qué
/// categoría es, en cuántos días se entrega y cuánto cuesta su unidad.
class CatalogoConceptos extends StatelessWidget {
  const CatalogoConceptos({
    super.key,
    required this.conceptos,
    required this.categorias,
    required this.busqueda,
    required this.categoriaId,
    required this.cantidadDe,
    required this.onBuscar,
    required this.onCategoria,
    required this.onAgregar,
  });

  /// Los conceptos que quedan tras el buscador y la categoría.
  final List<PrecioData> conceptos;

  final Iterable<CategoriaData> categorias;
  final String busqueda;

  /// La categoría elegida, o [sinCategoria] cuando están todas.
  final int categoriaId;

  /// Cuántas unidades de ese concepto lleva ya la orden.
  final double Function(PrecioData concepto) cantidadDe;

  final ValueChanged<String> onBuscar;
  final ValueChanged<int> onCategoria;
  final ValueChanged<PrecioData> onAgregar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const PasoTitulo(numero: '2', titulo: 'Prendas'),
        VRow(
          gutter: 12,
          align: VAlign.center,
          children: [
            VCol(
              cols: 6,
              sm: 6,
              child: SearchFilter(label: 'Buscar concepto', value: busqueda, onChanged: onBuscar),
            ),
            VCol(
              cols: 6,
              sm: 6,
              child: FiltroCategoria(
                categorias: categorias,
                seleccionada: categoriaId,
                onChanged: onCategoria,
                onQuitar: () => onCategoria(sinCategoria),
              ),
            ),
          ],
        ),
        Expanded(
          child: conceptos.isEmpty
              ? const _SinConceptos()
              : _Lista(conceptos: conceptos, cantidadDe: cantidadDe, onAgregar: onAgregar),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.conceptos, required this.cantidadDe, required this.onAgregar});

  final List<PrecioData> conceptos;
  final double Function(PrecioData concepto) cantidadDe;
  final ValueChanged<PrecioData> onAgregar;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conceptos.length,
      separatorBuilder: (context, _) => const Divider(height: 1),
      itemBuilder: (context, indice) {
        final concepto = conceptos[indice];

        return _Concepto(
          concepto: concepto,
          cantidad: cantidadDe(concepto),
          onAgregar: () => onAgregar(concepto),
        );
      },
    );
  }
}

class _Concepto extends StatelessWidget {
  const _Concepto({required this.concepto, required this.cantidad, required this.onAgregar});

  final PrecioData concepto;

  /// Cuántas unidades lleva ya la orden. En `0` todavía no se ha agregado.
  final double cantidad;

  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elegido = cantidad > 0;

    return ListTile(
      onTap: onAgregar,
      selected: elegido,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
      title: Text(concepto.descripcion),
      subtitle: Text(
        '${concepto.categoria} · ${concepto.diasFormato} · '
        '${concepto.tipoUnidad.value}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(concepto.importe.toStringAsFixed(2), style: theme.textTheme.titleSmall),
          if (elegido)
            // La cantidad que ya lleva la orden, en el sitio donde estaría el
            // botón: ya se agregó, y lo que importa ahora es cuánto va.
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primary,
              child: Text(
                _cantidadCorta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
        ],
      ),
    );
  }

  /// La cantidad sin decimales cuando no los necesita: `2`, no `2.0`; pero
  /// `1.5` cuando se cobra por kilo.
  String get _cantidadCorta => cantidad == cantidad.roundToDouble()
      ? cantidad.toStringAsFixed(0)
      : cantidad.toStringAsFixed(1);
}

class _SinConceptos extends StatelessWidget {
  const _SinConceptos();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: theme.colorScheme.outline),
            Text(
              'Ningún concepto coincide con la búsqueda.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
