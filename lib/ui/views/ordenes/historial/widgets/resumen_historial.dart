import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/colores_historial.dart';

/// En qué va la orden, antes de contar cómo llegó ahí: de quién es, cuánto se
/// ha pagado y cuánta ropa ha salido.
///
/// Son dos medidores y no una lista de cifras porque lo que se pregunta al
/// abrir el historial es "¿cuánto le falta?", y una barra lo contesta sin
/// leer: llena es que ya no falta nada.
class ResumenHistorial extends StatelessWidget {
  const ResumenHistorial({super.key, required this.orden});

  final OrdenDetalleData orden;

  /// Por debajo de este ancho los dos medidores se apilan.
  static const double _corteDosMedidores = 520;

  /// El mismo margen con el que la base da una orden por saldada.
  static const double _margen = 0.005;

  @override
  Widget build(BuildContext context) {
    final entregadas = orden.items.length - orden.pendientesPorEntregar;
    final debe = orden.restante > _margen;
    final faltan = orden.pendientesPorEntregar;

    final dinero = _Medidor(
      icono: Icons.payments_rounded,
      titulo: 'Pagado',
      cifra: orden.pagado.toStringAsFixed(2),
      deCuanto: 'de ${orden.total.toStringAsFixed(2)}',
      avance: orden.total > 0 ? orden.pagado / orden.total : 1,
      completo: !debe,
      pie: debe
          ? 'Queda a deber ${orden.restante.toStringAsFixed(2)}'
          : 'Pagada por completo',
    );

    final ropa = _Medidor(
      icono: Icons.checkroom_rounded,
      titulo: 'Entregado',
      cifra: '$entregadas',
      deCuanto: 'de ${_conceptos(orden.items.length)}',
      avance: orden.items.isEmpty ? 0 : entregadas / orden.items.length,
      completo: orden.todoEntregado,
      pie: switch (faltan) {
        0 when orden.items.isNotEmpty => 'Toda la ropa salió',
        0 => 'La orden no tiene ropa',
        1 => 'Falta entregar 1 concepto',
        _ => 'Faltan entregar $faltan conceptos',
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _Cliente(nombre: orden.cliente, recibida: orden.fechaCreacion),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _corteDosMedidores) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [dinero, ropa],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Expanded(child: dinero),
                  Expanded(child: ropa),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _conceptos(int cuantos) =>
    cuantos == 1 ? '1 concepto' : '$cuantos conceptos';

/// De quién es la orden y desde cuándo está en la tienda.
class _Cliente extends StatelessWidget {
  const _Cliente({required this.nombre, required this.recibida});

  final String nombre;
  final DateTime recibida;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      spacing: 12,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primary,
          child: Icon(Icons.person_rounded, size: 20, color: scheme.onPrimary),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: theme.textTheme.titleMedium),
              Text(
                'Recibida el ${recibida.formatFullDate}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una cifra con su barra: cuánto de algo ya está hecho.
///
/// Completo, la barra y el pie se pintan de verde: es lo que se busca con la
/// vista, y así se encuentra sin leer el número.
class _Medidor extends StatelessWidget {
  const _Medidor({
    required this.icono,
    required this.titulo,
    required this.cifra,
    required this.deCuanto,
    required this.avance,
    required this.completo,
    required this.pie,
  });

  final IconData icono;
  final String titulo;

  /// Lo hecho, en grande.
  final String cifra;

  /// De cuánto, a su lado y en chico: `de 170.00`.
  final String deCuanto;

  /// De 0 a 1.
  final double avance;
  final bool completo;

  /// Lo que falta, o que ya no falta nada.
  final String pie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = completo ? scheme.legible(Colors.green) : scheme.primary;
    final tenue = scheme.onSurfaceVariant;
    final borde = scheme.bordeTarjeta;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.fondoTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(icono, size: 18, color: tenue),
              Text(
                titulo,
                style: theme.textTheme.labelLarge?.copyWith(color: tenue),
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: cifra, style: theme.textTheme.headlineSmall),
                TextSpan(
                  text: '  $deCuanto',
                  style: theme.textTheme.bodyMedium?.copyWith(color: tenue),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avance.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Row(
            spacing: 6,
            children: [
              if (completo)
                Icon(Icons.check_circle_rounded, size: 16, color: color),
              Expanded(
                child: Text(
                  pie,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: completo ? color : tenue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
