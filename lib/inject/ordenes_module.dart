import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_servicio_orden_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_servicio_dao.dart';
import 'package:gestion_lavanderia/datasource/local/ordenes_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';

/// Todo lo que necesita el módulo de órdenes de servicio.
///
/// Son tres DAO porque una orden son tres tablas: la orden, la ropa que trae y
/// el historial de movimientos. Los tres se registran aquí, con la función a la
/// que pertenecen.
///
/// El datasource usa además el DAO de clientes —toda orden muestra a su
/// cliente—, que registra `clientes_module` y se resuelve por tipo.
class OrdenesModule extends ModuleInject {
  const OrdenesModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<OrdenServicioDao>(
        () => instance<AppDatabase>().ordenServicioDao,
      )
      ..registerLazySingleton<OrdenHistoryDao>(
        () => instance<AppDatabase>().ordenHistoryDao,
      )
      ..registerLazySingleton<ItemServicioOrdenDao>(
        () => instance<AppDatabase>().itemServicioOrdenDao,
      )
      ..registerLazySingleton<OrdenesLocalDatasource>(
        () => OrdenesLocalDatasource(
          instance(),
          instance(),
          instance(),
          instance(),
          instance(),
          instance(),
        ),
      );
  }
}
