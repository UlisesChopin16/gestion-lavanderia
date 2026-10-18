import 'package:get_it/get_it.dart';

/// El contenedor de dependencias de la aplicación.
///
/// Se expone con este nombre para que quien lo use lea
/// `instance<EmpresaLocalDatasource>()` sin tener que saber que detrás está
/// `GetIt`.
final GetIt instance = GetIt.instance;

/// Un grupo de dependencias que se registran juntas.
///
/// Cada módulo cubre una capa —las preferencias, la base, los datasources, los
/// servicios— y es el único lugar donde se dice cómo se construye lo que
/// aporta. Así agregar una dependencia es tocar un archivo y no una lista
/// central que crece sin orden, y cada módulo se puede registrar solo en una
/// prueba que no necesite el resto.
///
/// [injectAll] es asíncrono porque algunas dependencias no se pueden construir
/// de otra forma: `SharedPreferences` se obtiene esperando. Un módulo que no
/// tenga nada que esperar simplemente no usa `await`.
abstract class ModuleInject {
  const ModuleInject();

  /// Registra en [instance] todo lo que aporta el módulo.
  Future<void> injectAll();
}
