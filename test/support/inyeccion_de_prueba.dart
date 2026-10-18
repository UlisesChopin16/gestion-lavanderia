import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/inject/app_module.dart';
import 'package:gestion_lavanderia/services/logo_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deja el contenedor con las dependencias de la aplicación, cambiando sólo lo
/// que una prueba no puede usar de verdad.
///
/// Se registran todos los módulos de [AppModule] en lugar de armar a mano lo
/// que hace falta: así la prueba corre contra el mismo grafo que la aplicación
/// y no se queda atrás cuando se agrega una dependencia nueva. Lo que se reemplaza
/// después es [db] —una base en memoria, para no tocar el disco— y, si se pide,
/// [logos], porque el selector real abre el diálogo de archivos del sistema.
///
/// Las dos veces se reemplaza con `allowReassignment` y no desregistrando
/// primero: ninguna de las dos se ha construido todavía —son `lazySingleton`—,
/// así que no hay nada que desechar.
Future<void> registrarDependenciasDePrueba({
  required AppDatabase db,
  LogoStorage? logos,
}) async {
  SharedPreferences.setMockInitialValues({});

  await instance.reset();
  instance.allowReassignment = true;

  await const AppModule().injectAll();

  instance.registerLazySingleton<AppDatabase>(() => db);

  if (logos != null) {
    instance.registerLazySingleton<LogoStorage>(() => logos);
  }
}

/// Vacía el contenedor al terminar una prueba.
///
/// La base se cierra aparte: la registró la prueba sin función de desecho, para
/// que cerrarla sea decisión de quien la creó.
Future<void> limpiarDependenciasDePrueba() => instance.reset();
