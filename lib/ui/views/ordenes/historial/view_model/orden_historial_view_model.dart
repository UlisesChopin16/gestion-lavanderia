import 'package:collection/collection.dart' show mergeSort;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';

part 'orden_historial_view_model.freezed.dart';
part 'orden_historial_view_model.g.dart';

@freezed
sealed class OrdenHistorialState with _$OrdenHistorialState {
  const OrdenHistorialState._();

  const factory OrdenHistorialState({
    /// La orden con su historial. En `null` mientras se lee, o si ya no
    /// existe.
    OrdenDetalleData? orden,
    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _OrdenHistorialState;

  /// Lo que pasó con la orden, agrupado por día y del más reciente al más
  /// antiguo: lo último que se hizo es lo primero que se ve, que es lo que se
  /// busca al abrir el historial.
  ///
  /// Agrupado por día porque es como se recuerda en el mostrador: "vino el
  /// martes y pagó la mitad".
  ///
  /// Además de los movimientos van las veces que se terminó ropa. Marcarla
  /// lista no es un movimiento —no cobra ni saca nada—, así que no está en el
  /// historial de la base: se arma con la fecha que guarda cada prenda. Las
  /// que se marcaron juntas comparten la fecha y son un solo evento; las que
  /// se marcaron al registrar un cobro o una entrega tienen la de ese
  /// movimiento, y se cuentan dentro de él.
  List<DiaHistorial> get dias {
    final orden = this.orden;
    if (orden == null) return const [];

    final historial = orden.historial;
    final listas = _listasPorFecha(orden.items);

    final eventos = <EventoHistorial>[
      for (final (indice, movimiento) in historial.indexed)
        EventoMovimiento(
          movimiento: movimiento,
          // El último es el más antiguo: el del alta.
          tipo: movimiento.tipo(esAlta: indice == historial.length - 1),
          listas: listas.remove(movimiento.fecha) ?? const [],
        ),
      for (final MapEntry(key: fecha, value: items) in listas.entries)
        EventoListas(fecha: fecha, items: items),
    ];

    // La base entrega los movimientos del más reciente al más antiguo; las
    // marcas se intercalan por su fecha. Estable, para que dos movimientos
    // del mismo instante conserven el orden de la base.
    mergeSort(eventos, compare: (a, b) => b.fecha.compareTo(a.fecha));

    final dias = <DiaHistorial>[];
    for (final evento in eventos) {
      final dia = evento.fecha.soloDia;

      if (dias.lastOrNull case final ultimo? when ultimo.dia == dia) {
        ultimo.eventos.add(evento);
      } else {
        dias.add(DiaHistorial(dia: dia, eventos: [evento]));
      }
    }

    return dias;
  }

  /// La ropa que se marcó lista, agrupada por el instante en que se marcó.
  ///
  /// Queda fuera la que se dio por lista al entregarse sin marcarla antes
  /// —su fecha de lista es la de su entrega—: ya sale en la entrega, y
  /// repetirla como "lista" sería contar dos veces el mismo momento.
  static Map<DateTime, List<ItemOrdenData>> _listasPorFecha(
    List<ItemOrdenData> items,
  ) {
    final porFecha = <DateTime, List<ItemOrdenData>>{};

    for (final item in items) {
      final fecha = item.fechaLista;
      if (fecha == null || fecha == item.fechaEntregado) continue;

      porFecha.putIfAbsent(fecha, () => []).add(item);
    }

    return porFecha;
  }

  /// Cuántos registros tiene la línea: los movimientos y las veces que se
  /// terminó ropa, que también se ven en ella.
  int get movimientos => dias.fold(0, (suma, dia) => suma + dia.eventos.length);
}

/// Un día del historial con lo que pasó en él, de lo último a lo primero.
class DiaHistorial {
  DiaHistorial({required this.dia, required this.eventos});

  /// El día, sin la hora.
  final DateTime dia;
  final List<EventoHistorial> eventos;
}

/// Algo que pasó con la orden: un movimiento, o ropa que quedó lista.
sealed class EventoHistorial {
  const EventoHistorial();

  DateTime get fecha;
}

/// Un movimiento con el nombre de lo que pasó en él, que depende de su lugar
/// en el historial y no sólo de sus datos.
class EventoMovimiento extends EventoHistorial {
  const EventoMovimiento({
    required this.movimiento,
    required this.tipo,
    this.listas = const [],
  });

  final MovimientoData movimiento;
  final TipoMovimientoType tipo;

  /// La ropa que se marcó lista en el mismo movimiento: se terminó y se
  /// cobró, por ejemplo, en la misma visita.
  final List<ItemOrdenData> listas;

  @override
  DateTime get fecha => movimiento.fecha;
}

/// Ropa que se marcó lista para que el cliente pase por ella, sin cobrar ni
/// entregar nada.
class EventoListas extends EventoHistorial {
  const EventoListas({required this.fecha, required this.items});

  @override
  final DateTime fecha;

  final List<ItemOrdenData> items;
}

/// El historial de una orden: sólo se mira.
///
/// Lee la misma orden completa que el detalle —el historial ya viene anidado,
/// con la ropa de cada entrega—, pero no comparte su estado: aquel carga con
/// todo lo del cobro, y esto no cobra nada.
///
/// Es una familia por orden y se desecha al cerrar el diálogo, así que cada
/// vez que se abre lee la orden tal como está en la base.
@riverpod
class OrdenHistorialViewModel extends _$OrdenHistorialViewModel {
  final _ordenes = instance<OrdenesLocalDatasource>();

  @override
  OrdenHistorialState build(int ordenId) {
    Future.microtask(cargar);

    return const OrdenHistorialState();
  }

  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final orden = await _ordenes.detalle(ordenId);

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        orden: orden,
        mensajeError: orden == null ? 'La orden ya no existe.' : '',
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo leer el historial.\n$error\n$stackTrace');

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        mensajeError: error is SQLException
            ? error.message
            : 'No se pudo leer el historial de la orden.',
      );
    }
  }
}
