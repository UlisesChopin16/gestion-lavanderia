import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/reportes/cuentas_por_cobrar.dart';

part 'cuentas_por_cobrar_view_model.freezed.dart';
part 'cuentas_por_cobrar_view_model.g.dart';

@freezed
sealed class CuentasPorCobrarState with _$CuentasPorCobrarState {
  const factory CuentasPorCobrarState({
    /// En `null` mientras se cargan por primera vez, o si falló la carga.
    CuentasPorCobrar? cuentas,

    /// Qué grupo se ve en la lista; en `null`, todos.
    AntiguedadSaldo? antiguedad,

    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _CuentasPorCobrarState;
}

/// Las cuentas por cobrar en pantalla: las órdenes que deben algo, cuánto
/// llevan debiendo y a quién hay que llamar.
@riverpod
class CuentasPorCobrarViewModel extends _$CuentasPorCobrarViewModel {
  final _reportes = instance<ReportesLocalDatasource>();

  @override
  CuentasPorCobrarState build() {
    Future.microtask(recargar);
    return const CuentasPorCobrarState();
  }

  /// Ve sólo un grupo en la lista, o todos con `null`.
  void filtrar(AntiguedadSaldo? antiguedad) {
    state = state.copyWith(antiguedad: antiguedad);
  }

  /// Vuelve a leer: lo que se cobró desde que se abrió ya no se debe.
  Future<void> recargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final cuentas = await _reportes.cuentasPorCobrar();
      if (!ref.mounted) return;

      state = state.copyWith(cuentas: cuentas, cargando: false);
    } catch (error, stackTrace) {
      debugPrint('No se pudieron cargar las cuentas.\n$error\n$stackTrace');
      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        mensajeError: error is SQLException
            ? error.message
            : 'No se pudieron cargar las cuentas por cobrar.',
      );
    }
  }
}
