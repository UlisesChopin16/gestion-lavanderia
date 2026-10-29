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
  /// Es el orden en que la base lo entrega, así que no se invierte. Agrupado
  /// por día porque es como se recuerda en el mostrador: "vino el martes y
  /// pagó la mitad".
  List<DiaHistorial> get dias {
    final historial = orden?.historial ?? const <MovimientoData>[];
    final dias = <DiaHistorial>[];

    for (final (indice, movimiento) in historial.indexed) {
      final evento = EventoHistorial(
        movimiento: movimiento,
        // El último es el más antiguo: el del alta.
        tipo: movimiento.tipo(esAlta: indice == historial.length - 1),
      );
      final dia = movimiento.fecha.soloDia;

      if (dias.lastOrNull case final ultimo? when ultimo.dia == dia) {
        ultimo.eventos.add(evento);
      } else {
        dias.add(DiaHistorial(dia: dia, eventos: [evento]));
      }
    }

    return dias;
  }

  int get movimientos => orden?.historial.length ?? 0;
}

/// Un día del historial con lo que pasó en él, de lo último a lo primero.
class DiaHistorial {
  DiaHistorial({required this.dia, required this.eventos});

  /// El día, sin la hora.
  final DateTime dia;
  final List<EventoHistorial> eventos;
}

/// Un movimiento con el nombre de lo que pasó en él, que depende de su lugar
/// en el historial y no sólo de sus datos.
class EventoHistorial {
  const EventoHistorial({required this.movimiento, required this.tipo});

  final MovimientoData movimiento;
  final TipoMovimientoType tipo;
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
