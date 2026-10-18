import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/precios/precios_conceptos_dao.dart';
import 'package:gestion_lavanderia/datasource/local/precios_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';

/// Todo lo que necesita el módulo de precios —los conceptos de ropa—: su DAO y
/// su datasource.
///
/// Su DAO lo usan además categorías y órdenes: una categoría arrastra a sus
/// conceptos al desactivarse, y una orden necesita el precio de cada prenda.
/// Queda registrado aquí, con la función a la que pertenece, y los otros
/// módulos lo resuelven por tipo.
class PreciosModule extends ModuleInject {
  const PreciosModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<PreciosConceptosDao>(
        () => instance<AppDatabase>().preciosConceptosDao,
      )
      ..registerLazySingleton<PreciosLocalDatasource>(
        () => PreciosLocalDatasource(instance(), instance()),
      );
  }
}
