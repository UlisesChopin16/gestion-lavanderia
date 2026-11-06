import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/reportes/ropa_pendiente.dart';

part 'ropa_pendiente_view_model.freezed.dart';
part 'ropa_pendiente_view_model.g.dart';

/// Qué órdenes se ven en la lista de la ropa pendiente.
enum FiltroRopa {
  atrasada(titulo: 'Atrasada'),
  lista(titulo: 'Lista para recoger'),
  hoy(titulo: 'Para hoy'),
  todas(titulo: 'Todo lo pendiente');

  const FiltroRopa({required this.titulo});

  final String titulo;

  List<OrdenConRopaPendiente> de(RopaPendiente ropa) => switch (this) {
    atrasada => ropa.en(EstadoEntrega.atrasada),
    lista => ropa.conAlgoListo,
    hoy => ropa.en(EstadoEntrega.hoy),
    todas => ropa.ordenes,
  };
}

@freezed
sealed class RopaPendienteState with _$RopaPendienteState {
  const factory RopaPendienteState({
    /// En `null` mientras se carga por primera vez, o si falló la carga.
    RopaPendiente? ropa,

    /// De entrada lo atrasado: es por lo que se abre esta pantalla.
    @Default(FiltroRopa.atrasada) FiltroRopa filtro,

    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _RopaPendienteState;
}

/// La ropa pendiente en pantalla: lo atrasado, lo de hoy, lo que viene y lo
/// que ya está listo y nadie ha recogido.
@riverpod
class RopaPendienteViewModel extends _$RopaPendienteViewModel {
  final _reportes = instance<ReportesLocalDatasource>();

  @override
  RopaPendienteState build() {
    Future.microtask(recargar);
    return const RopaPendienteState();
  }

  void filtrar(FiltroRopa filtro) {
    state = state.copyWith(filtro: filtro);
  }

  /// Vuelve a leer: lo que se entregó desde que se abrió ya no está.
  Future<void> recargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final ropa = await _reportes.ropaPendiente();
      if (!ref.mounted) return;

      state = state.copyWith(ropa: ropa, cargando: false);
    } catch (error, stackTrace) {
      debugPrint('No se pudo cargar la ropa pendiente.\n$error\n$stackTrace');
      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        mensajeError: error is SQLException
            ? error.message
            : 'No se pudo cargar la ropa pendiente.',
      );
    }
  }
}
