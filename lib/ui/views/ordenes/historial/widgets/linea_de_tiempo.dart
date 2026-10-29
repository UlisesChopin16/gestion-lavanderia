import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/view_model/orden_historial_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/colores_historial.dart';

/// Lo que pasó con la orden, de lo más reciente al alta, sobre una línea.
///
/// Cada movimiento es un punto con el color de lo que se movió —verde el
/// dinero, azul la ropa— y una tarjeta con el detalle: cuánto, con qué, con
/// cuánto pagó y qué se llevó. Los días van como encabezados sobre la misma
/// línea, para que se vea cuánto tiempo pasó entre una visita y otra.
///
/// Arriba de todo va el desenlace: cómo se cerró la orden o, si sigue
/// abierta, lo que le falta. Es lo más reciente de todo —cómo está ahora— y la
/// pregunta con la que casi siempre se abre el historial.
class LineaDeTiempo extends StatelessWidget {
  const LineaDeTiempo({super.key, required this.dias, required this.orden});

  final List<DiaHistorial> dias;
  final OrdenDetalleData orden;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Desenlace(orden: orden, lineaAbajo: dias.isNotEmpty),
        for (final dia in dias) ...[
          _EncabezadoDia(dia: dia.dia),
          for (final evento in dia.eventos)
            _Evento(
              evento: evento,
              // Lo de hasta abajo es el alta: ahí empezó todo y la línea
              // no tiene a dónde seguir.
              ultimo: identical(evento, dias.last.eventos.last),
            ),
        ],
      ],
    );
  }
}

/// Un tramo de la línea: el punto a la izquierda, sobre la línea, y lo que
/// cuenta a la derecha.
///
/// La línea se dibuja en dos mitades —arriba y abajo del punto— para que el
/// primer tramo no tenga de dónde venir ni el último a dónde ir.
class _Tramo extends StatelessWidget {
  const _Tramo({
    required this.nodo,
    required this.child,
    this.lineaArriba = true,
    this.lineaAbajo = true,
  });

  final Widget nodo;
  final Widget child;
  final bool lineaArriba;
  final bool lineaAbajo;

  /// Lo que ocupa la columna de los puntos.
  static const double ancho = 36;

  /// A qué altura queda el centro del punto: el de un renglón de título.
  static const double centro = ancho / 2;

  static const double _grosor = 2;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    const izquierda = ancho / 2 - _grosor / 2;

    return Stack(
      children: [
        if (lineaArriba)
          Positioned(
            left: izquierda,
            top: 0,
            height: centro,
            width: _grosor,
            child: ColoredBox(color: color),
          ),
        if (lineaAbajo)
          Positioned(
            left: izquierda,
            top: centro,
            bottom: 0,
            width: _grosor,
            child: ColoredBox(color: color),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            SizedBox.square(
              dimension: ancho,
              child: Center(child: nodo),
            ),
            Expanded(child: child),
          ],
        ),
      ],
    );
  }
}

/// El círculo de un movimiento: el icono de lo que pasó, en su color.
class _Punto extends StatelessWidget {
  const _Punto({
    required this.icono,
    required this.color,
    this.relleno = false,
  });

  final IconData icono;
  final Color color;

  /// Relleno para el desenlace de una orden cerrada: es donde terminó, no un
  /// paso más.
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.legible(this.color);

    return Container(
      width: _Tramo.ancho,
      height: _Tramo.ancho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // El fondo opaco tapa la línea que pasa por detrás.
        color: relleno
            ? color
            : Color.alphaBlend(color.withValues(alpha: 0.15), scheme.surface),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icono, size: 18, color: relleno ? Colors.white : color),
    );
  }
}

/// El día, sobre la línea: "Hoy", "Ayer" o la fecha con su nombre.
class _EncabezadoDia extends StatelessWidget {
  const _EncabezadoDia({required this.dia});

  final DateTime dia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hoy = DateTime.now().soloDia;
    // Se arma el día de ayer y no se restan 24 horas: el día en que cambia el
    // horario dura 23 o 25, y la resta caería en el día equivocado.
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
    final fecha = dia.formatLongDate;

    final (principal, secundario) = switch (dia) {
      _ when dia == hoy => ('Hoy', fecha),
      _ when dia == ayer => ('Ayer', fecha),
      _ => (fecha.capitalize(), null),
    };

    return _Tramo(
      nodo: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.outline,
        ),
      ),
      child: SizedBox(
        height: _Tramo.ancho,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: principal, style: theme.textTheme.titleSmall),
                if (secundario != null)
                  TextSpan(
                    text: ' · $secundario',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Un movimiento: qué fue, a qué hora, lo que se cobró y lo que salió.
class _Evento extends StatelessWidget {
  const _Evento({required this.evento, required this.ultimo});

  final EventoHistorial evento;

  /// Si es el de hasta abajo: ahí se corta la línea.
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final movimiento = evento.movimiento;
    final tipo = evento.tipo;

    final nota = switch (tipo) {
      TipoMovimientoType.adelanto => 'Al recibir la ropa',
      TipoMovimientoType.alta => 'Se recibió la ropa sin adelanto',
      _ => null,
    };

    return _Tramo(
      lineaAbajo: !ultimo,
      nodo: _Punto(icono: tipo.icon, color: tipo.color),
      child: Padding(
        padding: EdgeInsets.only(bottom: ultimo ? 0 : 16),
        child: _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              _Titulo(
                titulo: tipo.titulo,
                nota: nota,
                hora: movimiento.fecha.formatTime,
              ),
              if (tipo.cobra) _Cobro(movimiento: movimiento, color: tipo.color),
              if (movimiento.huboEntrega)
                _Entregados(items: movimiento.entregados),
              // El saldo sólo donde cambió, o donde nació: en una entrega sin
              // cobro sería repetir el del movimiento anterior.
              if (tipo.cobra || tipo == TipoMovimientoType.alta)
                _Saldo(movimiento: movimiento),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.acento});

  final Widget child;

  /// El color de estado de la tarjeta, para el desenlace: lo lleva en el
  /// borde y, apenas, en el fondo, para que los dos digan lo mismo. Sin él es
  /// una tarjeta como cualquiera: sin borde en oscuro, con uno fino en claro.
  final Color? acento;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acento = this.acento;
    final borde = acento?.withValues(alpha: 0.6) ?? scheme.bordeTarjeta;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: acento == null
            ? scheme.fondoTarjeta
            : Color.alphaBlend(
                acento.withValues(alpha: scheme.tinte),
                scheme.fondoTarjeta,
              ),
        borderRadius: BorderRadius.circular(12),
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: child,
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.titulo, required this.hora, this.nota});

  final String titulo;
  final String hora;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenue = theme.colorScheme.onSurfaceVariant;
    final nota = this.nota;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: theme.textTheme.titleSmall),
              if (nota != null)
                Text(
                  nota,
                  style: theme.textTheme.bodySmall?.copyWith(color: tenue),
                ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: tenue),
            Text(
              hora,
              style: theme.textTheme.bodySmall?.copyWith(color: tenue),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cuánto se cobró y con qué; en efectivo, con cuánto pagó y su cambio.
class _Cobro extends StatelessWidget {
  const _Cobro({required this.movimiento, required this.color});

  final MovimientoData movimiento;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metodo = movimiento.metodoPago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 8,
          children: [
            // Lo que cede, si falta ancho, es el método y no el importe.
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Etiqueta(icono: metodo.icon, texto: metodo.value),
              ),
            ),
            Text(
              '+ ${movimiento.monto.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.legible(color),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (movimiento case MovimientoData(
          :final double recibido,
          :final double cambio,
        ))
          _Efectivo(recibido: recibido, cambio: cambio),
      ],
    );
  }
}

/// Una pastilla con icono: el método de pago.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icono, size: 16, color: scheme.onSurfaceVariant),
          Flexible(
            child: Text(
              texto,
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Con cuánto pagó el cliente en efectivo y cuánto se le devolvió.
///
/// Sin cambio sólo se dice que pagó justo: "Recibió 330.00 · cambio 0.00" es
/// leer dos números para enterarse de que no pasó nada.
class _Efectivo extends StatelessWidget {
  const _Efectivo({required this.recibido, required this.cambio});

  final double recibido;
  final double cambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenue = theme.colorScheme.onSurfaceVariant;
    final estilo = theme.textTheme.bodySmall?.copyWith(color: tenue);
    final conCambio = cambio > 0.005;

    return Row(
      spacing: 6,
      children: [
        Icon(Icons.local_atm_rounded, size: 14, color: tenue),
        Expanded(
          child: conCambio
              ? Text.rich(
                  TextSpan(
                    style: estilo,
                    children: [
                      TextSpan(text: 'Recibió ${recibido.toStringAsFixed(2)}'),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: 'Cambio ${cambio.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : Text('Pagó justo', style: estilo),
        ),
      ],
    );
  }
}

/// La ropa en cuadrícula: una celda por prenda, en tantas columnas como
/// quepan.
///
/// Una orden de diez prendas en lista era una columna que obligaba a
/// desplazar; en cuadrícula se ve entera de un vistazo.
///
/// Las columnas salen del ancho y no de cuántas prendas hay: así una prenda
/// sola no se estira de lado a lado, y las celdas miden lo mismo en todas las
/// tarjetas del historial.
class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.children});

  final List<Widget> children;

  /// Lo menos que mide una celda: lo que necesita un nombre de prenda, su
  /// cantidad y su importe sin cortarse.
  static const double _anchoMinimo = 220;
  static const double _separacion = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borde = scheme.bordeTarjeta;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = math.max(
          1,
          ((ancho + _separacion) / (_anchoMinimo + _separacion)).floor(),
        );
        final anchoCelda = (ancho - _separacion * (columnas - 1)) / columnas;

        return Wrap(
          spacing: _separacion,
          runSpacing: _separacion,
          children: [
            for (final child in children)
              Container(
                width: anchoCelda,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.fondoCelda,
                  borderRadius: BorderRadius.circular(8),
                  border: borde == null ? null : Border.all(color: borde),
                ),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

/// La ropa que salió en el movimiento.
class _Entregados extends StatelessWidget {
  const _Entregados({required this.items});

  final List<ItemOrdenData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cuantos = items.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: TipoMovimientoType.entrega.color.withValues(alpha: scheme.tinte),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            cuantos == 1
                ? 'Se entregó 1 concepto'
                : 'Se entregaron $cuantos conceptos',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          _Rejilla(children: [for (final item in items) _Prenda(item: item)]),
        ],
      ),
    );
  }
}

/// Una prenda: qué es, cuánto y lo que cuesta.
class _Prenda extends StatelessWidget {
  const _Prenda({required this.item, this.detalle});

  final ItemOrdenData item;

  /// Lo que va debajo del nombre en lugar de la cantidad: para cuándo se
  /// prometió, en lo que falta entregar.
  final Widget? detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenue = theme.colorScheme.onSurfaceVariant;
    final precio = item.precio;
    final detalle = this.detalle;

    return Row(
      spacing: 8,
      children: [
        Icon(Icons.checkroom_rounded, size: 16, color: tenue),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Un renglón cada texto: así las celdas de una misma fila
              // miden lo mismo y la cuadrícula no queda escalonada.
              Text(
                precio.descripcion,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              detalle ??
                  Text(
                    '${_cantidad(item.cantidad)} ${precio.tipoUnidad.value} · '
                    '${precio.categoria}',
                    style: theme.textTheme.bodySmall?.copyWith(color: tenue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ],
          ),
        ),
        Text(
          item.importe.toStringAsFixed(2),
          style: theme.textTheme.bodyMedium?.copyWith(color: tenue),
        ),
      ],
    );
  }
}

/// `2`, no `2.0`; pero `1.5` cuando se cobra por kilo.
String _cantidad(double cantidad) => cantidad == cantidad.roundToDouble()
    ? cantidad.toStringAsFixed(0)
    : cantidad.toStringAsFixed(1);

/// Cómo quedó la cuenta después del movimiento.
class _Saldo extends StatelessWidget {
  const _Saldo({required this.movimiento});

  final MovimientoData movimiento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tenue = scheme.onSurfaceVariant;
    final salda = movimiento.saldaLaOrden;
    final color = salda ? scheme.legible(Colors.green) : tenue;

    return Row(
      spacing: 6,
      children: [
        Icon(
          salda
              ? Icons.verified_rounded
              : Icons.account_balance_wallet_outlined,
          size: 16,
          color: color,
        ),
        Flexible(
          child: Text(
            salda
                ? 'Con esto quedó pagada'
                : 'Quedó a deber ${movimiento.restante.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: salda ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// La punta de la línea: cómo se cerró la orden, o lo que le falta.
class _Desenlace extends StatelessWidget {
  const _Desenlace({required this.orden, required this.lineaAbajo});

  final OrdenDetalleData orden;

  /// Si hay movimientos debajo con los que unirse.
  final bool lineaAbajo;

  @override
  Widget build(BuildContext context) {
    final estatus = orden.estatus;
    final cerrada = estatus == EstatusOrdenType.cerrada;
    final cancelada = estatus == EstatusOrdenType.cancelada;

    if (cerrada || cancelada) {
      return _Tramo(
        lineaArriba: false,
        lineaAbajo: lineaAbajo,
        nodo: _Punto(icono: estatus.icon, color: estatus.color, relleno: true),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _Tarjeta(
            acento: estatus.color,
            child: _Titulo(
              titulo: cancelada ? 'Orden cancelada' : 'Orden cerrada',
              nota: cancelada ? null : 'Pagada y entregada',
              hora: orden.fechaCierre?.formatFullDate ?? '',
            ),
          ),
        ),
      );
    }

    return _Tramo(
      lineaArriba: false,
      lineaAbajo: lineaAbajo,
      nodo: _Punto(
        icono: Icons.hourglass_top_rounded,
        color: EstatusOrdenType.enCurso.color,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _LoQueFalta(orden: orden),
      ),
    );
  }
}

/// Lo que le queda a una orden abierta: lo que debe y la ropa que no ha salido.
class _LoQueFalta extends StatelessWidget {
  const _LoQueFalta({required this.orden});

  final OrdenDetalleData orden;

  /// El mismo margen con el que la base da una orden por saldada.
  static const double _margen = 0.005;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pendientes = orden.pendientes;
    final debe = orden.restante > _margen;

    return _Tarjeta(
      acento: EstatusOrdenType.enCurso.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text('Lo que falta', style: theme.textTheme.titleSmall),
          if (debe)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Queda a deber',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  orden.restante.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (pendientes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  pendientes.length == 1
                      ? 'Falta entregar 1 concepto'
                      : 'Faltan entregar ${pendientes.length} conceptos',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                _Rejilla(
                  children: [
                    for (final item in pendientes)
                      _Prenda(
                        item: item,
                        detalle: _Promesa(item: item),
                      ),
                  ],
                ),
              ],
            ),
          if (!debe && pendientes.isEmpty)
            Text(
              'No le queda nada pendiente.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Para cuándo se prometió la prenda, en rojo si ya pasó: es la que el
/// cliente viene a reclamar.
class _Promesa extends StatelessWidget {
  const _Promesa({required this.item});

  final ItemOrdenData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Contra el principio de hoy: lo prometido para hoy todavía está a tiempo.
    final atrasada = item.fechaEntrega.isBefore(DateTime.now().soloDia);
    final fecha = item.fechaEntrega.formatDate;

    return Text(
      atrasada ? 'Atrasada · era para el $fecha' : 'Para el $fecha',
      style: theme.textTheme.bodySmall?.copyWith(
        color: atrasada ? scheme.error : scheme.onSurfaceVariant,
      ),
    );
  }
}
