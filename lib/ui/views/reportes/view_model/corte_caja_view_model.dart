import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';

part 'corte_caja_view_model.freezed.dart';
part 'corte_caja_view_model.g.dart';

@freezed
sealed class CorteCajaState with _$CorteCajaState {
  const factory CorteCajaState({
    /// El día del corte, a medianoche.
    required DateTime dia,

    /// En `null` mientras se cargan por primera vez, o si falló la carga.
    EstadisticasCorte? estadisticas,
    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _CorteCajaState;
}

/// El corte de caja en pantalla: el día elegido —hoy, de entrada— con sus
/// cifras y sus gráficas.
@riverpod
class CorteCajaViewModel extends _$CorteCajaViewModel {
  final _reportes = instance<ReportesLocalDatasource>();

  @override
  CorteCajaState build() {
    final hoy = DateTime.now().soloDia;
    Future.microtask(() => _cargar(hoy));

    return CorteCajaState(dia: hoy);
  }

  /// Cambia de día y lo carga. No pasa de hoy: mañana no se ha cobrado nada.
  Future<void> elegirDia(DateTime dia) {
    final hoy = DateTime.now().soloDia;
    final elegido = dia.soloDia.isAfter(hoy) ? hoy : dia.soloDia;

    return _cargar(elegido);
  }

  /// El día anterior o el siguiente al que se ve.
  Future<void> moverDia(int dias) {
    final dia = state.dia;
    return elegirDia(DateTime(dia.year, dia.month, dia.day + dias));
  }

  /// Vuelve a leer el día que se ve: lo que se cobró desde que se abrió.
  Future<void> recargar() => _cargar(state.dia);

  Future<void> _cargar(DateTime dia) async {
    state = state.copyWith(dia: dia, cargando: true, mensajeError: '');

    try {
      final estadisticas = await _reportes.estadisticasCorte(dia);

      // Si mientras tanto se pidió otro día, esta respuesta ya no sirve.
      if (!ref.mounted || state.dia != dia) return;

      state = state.copyWith(estadisticas: estadisticas, cargando: false);
    } catch (error, stackTrace) {
      debugPrint('No se pudo cargar el corte de caja.\n$error\n$stackTrace');

      if (!ref.mounted || state.dia != dia) return;

      state = state.copyWith(
        cargando: false,
        mensajeError: error is SQLException
            ? error.message
            : 'No se pudo cargar el corte de caja.',
      );
    }
  }
}
