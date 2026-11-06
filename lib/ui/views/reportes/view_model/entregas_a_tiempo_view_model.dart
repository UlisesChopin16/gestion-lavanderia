import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/reportes/entregas_a_tiempo.dart';
export 'package:gestion_lavanderia/models/data/reportes/periodo_reporte.dart';

part 'entregas_a_tiempo_view_model.freezed.dart';
part 'entregas_a_tiempo_view_model.g.dart';

@freezed
sealed class EntregasATiempoState with _$EntregasATiempoState {
  const factory EntregasATiempoState({
    /// De entrada un mes: lo bastante para que el porcentaje diga algo.
    @Default(PeriodoReporte.mes) PeriodoReporte periodo,

    /// En `null` mientras se cargan por primera vez, o si falló la carga.
    EntregasATiempo? entregas,

    /// Qué categoría se ve en la lista de lo entregado tarde; en `null`,
    /// todas.
    String? categoria,

    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _EntregasATiempoState;
}

/// Las entregas a tiempo en pantalla: de lo que se entregó en el periodo,
/// cuánto salió en la fecha prometida y qué se atrasó.
@riverpod
class EntregasATiempoViewModel extends _$EntregasATiempoViewModel {
  final _reportes = instance<ReportesLocalDatasource>();

  /// Los periodos que se ofrecen: hoy es muy poco para un porcentaje, y uno
  /// a mano no hace falta para ver si se cumple.
  static const periodos = [
    PeriodoReporte.semana,
    PeriodoReporte.mes,
    PeriodoReporte.tresMeses,
    PeriodoReporte.anio,
  ];

  @override
  EntregasATiempoState build() {
    Future.microtask(recargar);
    return const EntregasATiempoState();
  }

  Future<void> elegirPeriodo(PeriodoReporte periodo) {
    state = state.copyWith(periodo: periodo, categoria: null);
    return recargar();
  }

  void filtrar(String? categoria) {
    state = state.copyWith(categoria: categoria);
  }

  Future<void> recargar() async {
    final periodo = state.periodo;
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final entregas = await _reportes.entregasATiempo(
        periodo.rangoDesde(DateTime.now())!,
      );

      // Si mientras tanto se pidió otro periodo, esta respuesta ya no sirve.
      if (!ref.mounted || state.periodo != periodo) return;

      state = state.copyWith(entregas: entregas, cargando: false);
    } catch (error, stackTrace) {
      debugPrint('No se pudieron cargar las entregas.\n$error\n$stackTrace');
      if (!ref.mounted || state.periodo != periodo) return;

      state = state.copyWith(
        cargando: false,
        mensajeError: error is SQLException
            ? error.message
            : 'No se pudieron cargar las entregas.',
      );
    }
  }
}
