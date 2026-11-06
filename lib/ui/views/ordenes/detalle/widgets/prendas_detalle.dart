import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/paso_prenda.dart';

/// La ropa de la orden en una sola lista: lo que ya salió y lo que falta.
///
/// Una sola y no dos —pendientes arriba, entregadas abajo— porque lo que se
/// compara al entregar es la orden entera contra lo que hay en el mostrador.
///
/// Cada prenda dice en qué paso está y deja elegir hasta dónde llega ahora:
/// `En proceso | Lista | Entregar`. Antes eran una casilla para entregar y una
/// etiqueta "Lista" sueltas, que no decían qué eran y se podían contradecir
/// —una prenda por entregar que no estaba lista—. Con los pasos en fila, lo
/// que se elige incluye lo de antes: entregar es también dejarla lista.
///
/// Lo que la base ya tiene no se puede regresar: el paso guardado y los de
/// antes se ven apagados. Lo que se eligió y todavía no se guarda se ve sobre
/// fondo, para que al pulsar el botón de abajo se sepa qué va a cambiar.
class PrendasDetalle extends StatelessWidget {
  const PrendasDetalle({
    super.key,
    required this.items,
    required this.editable,
    required this.pasoDe,
    required this.cambiaDePaso,
    required this.puedeLlevarTodoA,
    required this.hayPasosElegidos,
    required this.onPaso,
    required this.onTodo,
    required this.onDeshacer,
  });

  final List<ItemOrdenData> items;

  /// Si se puede mover la ropa. En una orden cerrada o cancelada la lista
  /// sólo se mira.
  final bool editable;

  /// El paso en el que quedará cada prenda al guardar.
  final PasoPrenda Function(ItemOrdenData item) pasoDe;

  /// Si a una prenda se le eligió un paso que todavía no está guardado.
  final bool Function(ItemOrdenData item) cambiaDePaso;

  /// Si alguna prenda puede avanzar hasta un paso: es lo que decide si se
  /// ofrece "Todo listo" o "Entregar todo".
  final bool Function(PasoPrenda paso) puedeLlevarTodoA;

  final bool hayPasosElegidos;

  final void Function(ItemOrdenData item, PasoPrenda paso) onPaso;
  final ValueChanged<PasoPrenda> onTodo;
  final VoidCallback onDeshacer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _Encabezado(
          entregadas: items.where((item) => item.estaEntregado).length,
          listas: items.where((item) => item.esperaAlCliente).length,
          total: items.length,
          todoListo: editable && puedeLlevarTodoA(PasoPrenda.lista),
          entregarTodo: editable && puedeLlevarTodoA(PasoPrenda.entregada),
          deshacer: editable && hayPasosElegidos,
          onTodo: onTodo,
          onDeshacer: onDeshacer,
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(height: 4),
            itemBuilder: (context, indice) {
              final item = items[indice];

              return _Renglon(
                item: item,
                paso: pasoDe(item),
                cambia: cambiaDePaso(item),
                editable: editable && item.estaPendiente,
                onPaso: (paso) => onPaso(item, paso),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// El título con la cuenta de la ropa, y los atajos para moverla toda.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.entregadas,
    required this.listas,
    required this.total,
    required this.todoListo,
    required this.entregarTodo,
    required this.deshacer,
    required this.onTodo,
    required this.onDeshacer,
  });

  final int entregadas;

  /// Las que están listas y esperan al cliente.
  final int listas;
  final int total;

  /// Qué atajos se ofrecen: sólo los que harían algo.
  final bool todoListo;
  final bool entregarTodo;
  final bool deshacer;

  final ValueChanged<PasoPrenda> onTodo;
  final VoidCallback onDeshacer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cuenta = [
      if (listas > 0) listas == 1 ? '1 lista' : '$listas listas',
      '$entregadas de $total entregadas',
    ].join(' · ');

    // Los botones bajan de renglón cuando no caben junto al título.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text('Prendas', style: theme.textTheme.titleMedium),
            Text(
              cuenta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (todoListo)
              TextButton.icon(
                onPressed: () => onTodo(PasoPrenda.lista),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Todo listo'),
              ),
            if (entregarTodo)
              TextButton.icon(
                onPressed: () => onTodo(PasoPrenda.entregada),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Entregar todo'),
              ),
            if (deshacer)
              IconButton(
                onPressed: onDeshacer,
                icon: const Icon(Icons.undo_rounded, size: 20),
                tooltip: 'Deshacer lo que se marcó',
              ),
          ],
        ),
      ],
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.item,
    required this.paso,
    required this.cambia,
    required this.editable,
    required this.onPaso,
  });

  final ItemOrdenData item;

  /// El paso en el que quedará al guardar.
  final PasoPrenda paso;

  /// Si ese paso todavía no está guardado.
  final bool cambia;

  /// Si se puede mover: sólo la ropa pendiente de una orden que todavía
  /// admite movimientos.
  final bool editable;

  final ValueChanged<PasoPrenda> onPaso;

  /// Lo que mide el lugar de los pasos, el mismo en todos los renglones para
  /// que los importes queden a plomo.
  static const double _anchoPasos = 252;

  /// Lo que el renglón necesita para llevar los pasos al lado: los pasos más
  /// lo que pide el nombre para leerse. Por debajo, van debajo.
  static const double _anchoEnLinea = _anchoPasos + 210;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final datos = _Datos(item: item);
    final pasos = SizedBox(
      width: _anchoPasos,
      child: editable
          ? _SelectorPaso(item: item, paso: paso, onPaso: onPaso)
          : _PasoFijo(paso: paso),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: cambia
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cambia
              ? scheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _anchoEnLinea) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [datos, pasos],
            );
          }

          return Row(
            spacing: 12,
            children: [
              Expanded(child: datos),
              pasos,
            ],
          );
        },
      ),
    );
  }
}

/// Qué es la prenda, cuánto cuesta y cómo va.
class _Datos extends StatelessWidget {
  const _Datos({required this.item});

  final ItemOrdenData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final precio = item.precio;
    final detalle = item.detalle;

    // Una pieza sola no se cuenta —es una—; lo demás dice cuánto lleva.
    final unaPieza = item.esPorPieza && item.cantidad == 1;
    final cantidad =
        '${_cantidad(item.cantidad)} '
        '${item.cantidad == 1 ? precio.tipoUnidad.value : precio.tipoUnidad.plural}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Expanded(
              // La descripción va junto al nombre, que es donde se busca
              // cuál de las playeras es: "Playera  blanca, manga larga".
              child: Text.rich(
                TextSpan(
                  text: precio.descripcion,
                  style: theme.textTheme.titleSmall,
                  children: [
                    if (detalle.isNotEmpty)
                      TextSpan(
                        text: '  $detalle',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Text(
              item.importe.toStringAsFixed(2),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        Text(
          unaPieza ? precio.categoria : '${precio.categoria} · $cantidad',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        _Fecha(item: item),
      ],
    );
  }
}

/// Los tres pasos, para elegir hasta dónde llega la prenda ahora.
///
/// Los que ya pasaron se ven apagados: una prenda lista no vuelve a estar en
/// proceso. El color del elegido es el del paso, el mismo con el que el
/// renglón lo dice debajo del nombre.
class _SelectorPaso extends StatelessWidget {
  const _SelectorPaso({
    required this.item,
    required this.paso,
    required this.onPaso,
  });

  final ItemOrdenData item;
  final PasoPrenda paso;
  final ValueChanged<PasoPrenda> onPaso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final guardado = PasoPrenda.de(item);

    final (fondo, texto) = switch (paso) {
      PasoPrenda.enProceso => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PasoPrenda.lista => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      PasoPrenda.entregada => (scheme.primary, scheme.onPrimary),
    };

    return SegmentedButton<PasoPrenda>(
      segments: [
        for (final opcion in PasoPrenda.values)
          ButtonSegment(
            value: opcion,
            label: Text(opcion.etiqueta, maxLines: 1, softWrap: false),
            enabled: opcion.alcanza(guardado),
          ),
      ],
      selected: {paso},
      onSelectionChanged: (elegidos) => onPaso(elegidos.single),
      // Sin la palomita: cambia el ancho del elegido y el fondo ya lo dice.
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: fondo,
        selectedForegroundColor: texto,
        textStyle: theme.textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// El paso de una prenda que ya no se mueve: entregada, o de una orden
/// cerrada o cancelada.
class _PasoFijo extends StatelessWidget {
  const _PasoFijo({required this.paso});

  final PasoPrenda paso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icono, texto, color) = switch (paso) {
      PasoPrenda.enProceso => (
        Icons.hourglass_empty_rounded,
        'En proceso',
        scheme.onSurfaceVariant,
      ),
      PasoPrenda.lista => (Icons.inventory_2_rounded, 'Lista', scheme.tertiary),
      PasoPrenda.entregada => (
        Icons.check_circle_rounded,
        'Entregada',
        scheme.primary,
      ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 6,
      children: [
        Icon(icono, size: 18, color: color),
        Text(texto, style: theme.textTheme.labelLarge?.copyWith(color: color)),
      ],
    );
  }
}

/// `2`, no `2.0`; pero `1.5` cuando se cobra por kilo.
String _cantidad(double cantidad) => cantidad == cantidad.roundToDouble()
    ? cantidad.toStringAsFixed(0)
    : cantidad.toStringAsFixed(1);

/// Cuándo salió el renglón, o para cuándo se prometió.
///
/// Una prenda pendiente cuya fecha ya pasó se avisa en rojo: es la que el
/// cliente viene a reclamar, y la que hay que buscar primero.
class _Fecha extends StatelessWidget {
  const _Fecha({required this.item});

  final ItemOrdenData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icono, texto, color) = switch (item) {
      ItemOrdenData(estaEntregado: true, :final fechaEntregado) => (
        Icons.check_circle_rounded,
        'Entregada el ${fechaEntregado.formatDate}',
        scheme.primary,
      ),
      ItemOrdenData(:final fechaLista?) => (
        Icons.inventory_2_rounded,
        'Lista desde el ${fechaLista.formatDate}',
        scheme.tertiary,
      ),
      _ when _atrasada => (
        Icons.warning_amber_rounded,
        'Atrasada · era para el ${item.fechaEntrega.formatDate}',
        scheme.error,
      ),
      _ => (
        Icons.event_rounded,
        'Para el ${item.fechaEntrega.formatDate}',
        scheme.onSurfaceVariant,
      ),
    };

    return Row(
      spacing: 4,
      children: [
        Icon(icono, size: 14, color: color),
        Flexible(
          child: Text(
            texto,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  /// Se compara contra el principio de hoy: una prenda que se prometió para
  /// hoy todavía está a tiempo.
  bool get _atrasada {
    final ahora = DateTime.now();

    return item.fechaEntrega.isBefore(
      DateTime(ahora.year, ahora.month, ahora.day),
    );
  }
}
