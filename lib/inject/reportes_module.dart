import 'package:gestion_lavanderia/datasource/local/reportes_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:gestion_lavanderia/services/reportes/corte_caja_pdf.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_excel.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_pdf.dart';

/// Todo lo que necesita la sección de reportes.
///
/// Lee de los DAO de órdenes, que registra `ordenes_module` y se resuelven
/// por tipo. Generar el PDF o el Excel no sale de la aplicación; guardarlo
/// sí —abre el diálogo del sistema—, y por eso es un servicio que una prueba
/// cambia por uno falso.
class ReportesModule extends ModuleInject {
  const ReportesModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<ReportesLocalDatasource>(
        () => ReportesLocalDatasource(instance(), instance()),
      )
      ..registerLazySingleton<ReporteVentasPdf>(ReporteVentasPdf.new)
      ..registerLazySingleton<ReporteVentasExcel>(ReporteVentasExcel.new)
      ..registerLazySingleton<CorteCajaPdf>(CorteCajaPdf.new)
      ..registerLazySingleton<GuardadoArchivo>(GuardadoArchivo.new);
  }
}
