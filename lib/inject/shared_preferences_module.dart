import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que se guarda en el equipo: las preferencias y los filtros con los que
/// quedó cada listado.
///
/// Como la base, no corresponde a una función de la aplicación sino que las
/// atraviesa: [FiltrosStore] es la cara con tipos de esas mismas preferencias y
/// lo usan los listados de clientes, categorías, precios y órdenes, así que se
/// registra junto a ellas y no en el módulo de uno de los cuatro.
///
/// Es el único módulo que espera algo: la instancia de [SharedPreferences] se
/// obtiene de forma asíncrona, así que se resuelve aquí una vez y se registra
/// ya construida. A cambio, todo lo que la use la lee de forma síncrona y
/// ninguna pantalla tiene que esperar dos veces.
class SharedPreferencesModule extends ModuleInject {
  const SharedPreferencesModule();

  @override
  Future<void> injectAll() async {
    final preferencias = await SharedPreferences.getInstance();

    instance
      ..registerLazySingleton<SharedPreferences>(() => preferencias)
      ..registerLazySingleton<FiltrosStore>(() => FiltrosStore(instance()));
  }
}
