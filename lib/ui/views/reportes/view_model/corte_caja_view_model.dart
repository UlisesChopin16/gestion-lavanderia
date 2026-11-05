import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:gestion_lavanderia/services/reportes/corte_caja_pdf.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'corte_caja_view_model.freezed.dart';
part 'corte_caja_view_model.g.dart';

@freezed
sealed class CorteCajaState with _$CorteCajaState {
  const factory CorteCajaState({
    /// El día del corte, a medianoche.
    required DateTime dia,
    @Default(false) bool generando,
    @Default('') String mensajeError,
  }) = _CorteCajaState;
}

/// El corte de caja: se elige el día —hoy, de entrada—, se genera el PDF y
/// se guarda.
@riverpod
class CorteCajaViewModel extends _$CorteCajaViewModel {
  final _reportes = instance<ReportesLocalDatasource>();
  final _empresas = instance<EmpresaLocalDatasource>();
  final _pdf = instance<CorteCajaPdf>();
  final _guardado = instance<GuardadoArchivo>();

  @override
  CorteCajaState build() => CorteCajaState(dia: DateTime.now().soloDia);

  void elegirDia(DateTime dia) {
    state = state.copyWith(dia: dia.soloDia, mensajeError: '');
  }

  /// Genera el corte y pide dónde guardarlo. Devuelve lo que se hizo, dicho
  /// para el aviso, o `null` si se canceló o falló: el porqué queda en
  /// [CorteCajaState.mensajeError].
  Future<String?> generar({DateTime? ahora}) async {
    if (state.generando) return null;

    state = state.copyWith(generando: true, mensajeError: '');

    try {
      final corte = await _reportes.corteCaja(state.dia, ahora: ahora);
      final empresa = await _empresas.empresa();

      final ruta = await _guardado.guardar(
        await _pdf.generar(corte, empresa: empresa),
        nombre: nombreArchivo(state.dia),
        extension: 'pdf',
        titulo: 'Guardar el corte de caja',
      );

      if (ref.mounted) state = state.copyWith(generando: false);

      return ruta == null ? null : 'El corte de caja se guardó en $ruta';
    } catch (error, stackTrace) {
      debugPrint('No se pudo generar el corte de caja.\n$error\n$stackTrace');

      if (ref.mounted) {
        state = state.copyWith(
          generando: false,
          mensajeError: error is SQLException
              ? error.message
              : 'No se pudo generar el corte de caja.',
        );
      }

      return null;
    }
  }

  /// `Corte de caja 2026-11-04.pdf`, con la fecha al revés de como se lee
  /// para que en la carpeta queden en orden.
  static String nombreArchivo(DateTime dia) {
    String dosCifras(int numero) => numero.toString().padLeft(2, '0');

    return 'Corte de caja ${dia.year}-${dosCifras(dia.month)}-'
        '${dosCifras(dia.day)}.pdf';
  }
}
