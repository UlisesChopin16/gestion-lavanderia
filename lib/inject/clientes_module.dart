import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_dao.dart';
import 'package:gestion_lavanderia/datasource/local/clientes_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';

/// Todo lo que necesita el módulo de clientes: su DAO y su datasource.
///
/// Cuando clientes tenga repositorio o servicios propios, se registran aquí: la
/// idea de un módulo por función es que para saber de qué depende una pantalla
/// baste abrir un archivo.
///
/// El DAO se pide a la conexión ya abierta en lugar de construirlo, porque en
/// drift los DAO son accesorios de la base y no objetos independientes. Se
/// registra de todas formas para que el datasource se arme resolviendo por
/// tipo con `instance()`, sin tener que saber de qué propiedad de la base sale.
class ClientesModule extends ModuleInject {
  const ClientesModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<ClientesDao>(
        () => instance<AppDatabase>().clientesDao,
      )
      ..registerLazySingleton<ClientesLocalDatasource>(
        () => ClientesLocalDatasource(instance(), instance()),
      );
  }
}
