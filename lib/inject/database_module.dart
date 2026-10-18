import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';

/// La conexión a la base de datos.
///
/// Es el único módulo que no corresponde a una función de la aplicación: la
/// base la comparten todas. Los DAO y los datasources de cada módulo se
/// registran con su función —`clientes_module`, `ordenes_module`— y resuelven
/// esta conexión por tipo.
///
/// Que sea un `lazySingleton` no es una preferencia sino un requisito: dos
/// conexiones a la vez sobre el mismo archivo se estorban entre sí. Y al ser
/// perezosa, el archivo no se abre hasta que alguna pantalla lo pide.
class DatabaseModule extends ModuleInject {
  const DatabaseModule();

  @override
  Future<void> injectAll() async {
    instance.registerLazySingleton<AppDatabase>(
      AppDatabase.new,
      // Cierra la conexión al vaciar el contenedor, que en las pruebas es al
      // final de cada caso: una base abierta mantiene bloqueado el archivo.
      dispose: (db) => db.close(),
    );
  }
}
