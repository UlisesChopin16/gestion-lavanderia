import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_excel.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_pdf.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';

part 'reporte_ventas_view_model.freezed.dart';
part 'reporte_ventas_view_model.g.dart';

// `makeCollectionsUnmodifiable: false`: freezed 3.0.4 genera un parámetro
// `final` para los campos de lista, que no compila. Ver `MovimientoData`.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class ReporteVentasState with _$ReporteVentasState {
  const ReporteVentasState._();

  const factory ReporteVentasState({
    @Default(PeriodoReporte.hoy) PeriodoReporte periodo,

    /// Las fechas de [PeriodoReporte.rango], tal como las entrega el
    /// calendario: vacía, con una mientras se elige la segunda, o con dos.
    @Default(<DateTime?>[]) List<DateTime?> fechas,

    @Default(false) bool generando,
    @Default('') String mensajeError,
  }) = _ReporteVentasState;

  /// Los días que abarcaría el reporte si se generara [ahora], o `null` si
  /// faltan las fechas.
  ///
  /// Con una sola fecha elegida, el reporte es de ese día: es lo que se pide
  /// al tocar un día y aceptar.
  RangoReporte? rangoAl(DateTime ahora) {
    if (periodo != PeriodoReporte.rango) return periodo.rangoDesde(ahora);

    final elegidas = fechas.nonNulls.toList();

    return switch (elegidas) {
      [final dia] => RangoReporte(dia, dia),
      [final desde, final hasta, ...] => RangoReporte(desde, hasta),
      _ => null,
    };
  }
}

/// El reporte general de ventas: se elige el periodo, se genera y se guarda.
///
/// Sale en PDF hasta un mes y en Excel de ahí en adelante; quien lo pide no
/// lo elige, pero el diálogo le dice en cuál saldrá antes de generarlo.
@riverpod
class ReporteVentasViewModel extends _$ReporteVentasViewModel {
  final _reportes = instance<ReportesLocalDatasource>();
  final _empresas = instance<EmpresaLocalDatasource>();
  final _pdf = instance<ReporteVentasPdf>();
  final _excel = instance<ReporteVentasExcel>();
  final _guardado = instance<GuardadoArchivo>();

  @override
  ReporteVentasState build() => const ReporteVentasState();

  void elegirPeriodo(PeriodoReporte periodo) {
    state = state.copyWith(periodo: periodo, mensajeError: '');
  }

  void elegirFechas(List<DateTime?> fechas) {
    state = state.copyWith(fechas: fechas, mensajeError: '');
  }

  /// Genera el reporte y pide dónde guardarlo. Devuelve lo que se hizo,
  /// dicho para el aviso, o `null` si se canceló o falló: el porqué queda en
  /// [ReporteVentasState.mensajeError].
  Future<String?> generar({DateTime? ahora}) async {
    if (state.generando) return null;

    final rango = state.rangoAl(ahora ?? DateTime.now());
    if (rango == null) {
      state = state.copyWith(mensajeError: 'Elige las fechas del reporte.');
      return null;
    }

    state = state.copyWith(generando: true, mensajeError: '');

    try {
      final reporte = await _reportes.ventas(rango, ahora: ahora);
      final empresa = (await _empresas.empresa())?.nombre ?? '';
      final formato = rango.formato;
      final archivo = switch (formato) {
        FormatoReporte.pdf => await _pdf.generar(reporte, empresa: empresa),
        FormatoReporte.excel => _excel.generar(reporte, empresa: empresa),
      };

      final ruta = await _guardado.guardar(
        archivo,
        nombre: nombreArchivo(rango, formato),
        extension: formato.extension,
        titulo: 'Guardar el reporte',
      );

      if (ref.mounted) state = state.copyWith(generando: false);

      return ruta == null ? null : 'El reporte se guardó en $ruta';
    } catch (error, stackTrace) {
      debugPrint('No se pudo generar el reporte.\n$error\n$stackTrace');

      if (ref.mounted) {
        state = state.copyWith(
          generando: false,
          mensajeError: error is SQLException
              ? error.message
              : 'No se pudo generar el reporte.',
        );
      }

      return null;
    }
  }

  /// `Reporte de ventas 2026-10-05 al 2026-11-04.xlsx`. Con la fecha al
  /// revés de como se lee, para que en la carpeta queden en orden.
  static String nombreArchivo(RangoReporte rango, FormatoReporte formato) {
    String dia(DateTime fecha) =>
        '${fecha.year}-${_dosCifras(fecha.month)}-${_dosCifras(fecha.day)}';

    final periodo = rango.desde == rango.hasta
        ? dia(rango.desde)
        : '${dia(rango.desde)} al ${dia(rango.hasta)}';

    return 'Reporte de ventas $periodo.${formato.extension}';
  }

  static String _dosCifras(int numero) => numero.toString().padLeft(2, '0');
}
