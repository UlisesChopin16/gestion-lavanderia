import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/configuracion_empresa_dao.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/direccion_dao.dart';
import 'package:gestion_lavanderia/datasource/local/empresa_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/logo_storage.dart';

/// Todo lo que necesita el módulo de configuración de la empresa: los DAO de
/// la empresa y su dirección, el datasource y el servicio que guarda el logo.
///
/// [LogoStorage] está aquí y no en un módulo de servicios porque sólo lo usa
/// esta pantalla. Está registrado —y no construido donde se usa— porque sale
/// de la aplicación: abre el diálogo de archivos del sistema, así que una
/// prueba lo reemplaza por uno falso.
class EmpresaModule extends ModuleInject {
  const EmpresaModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<ConfiguracionEmpresaDao>(
        () => instance<AppDatabase>().configuracionEmpresaDao,
      )
      ..registerLazySingleton<DireccionDao>(
        () => instance<AppDatabase>().direccionDao,
      )
      ..registerLazySingleton<EmpresaLocalDatasource>(
        () => EmpresaLocalDatasource(instance(), instance(), instance()),
      )
      ..registerLazySingleton<LogoStorage>(LogoStorage.new);
  }
}
