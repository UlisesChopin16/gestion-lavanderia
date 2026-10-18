import 'package:gestion_lavanderia/inject/categorias_module.dart';
import 'package:gestion_lavanderia/inject/clientes_module.dart';
import 'package:gestion_lavanderia/inject/database_module.dart';
import 'package:gestion_lavanderia/inject/empresa_module.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/inject/ordenes_module.dart';
import 'package:gestion_lavanderia/inject/precios_module.dart';
import 'package:gestion_lavanderia/inject/shared_preferences_module.dart';

export 'package:gestion_lavanderia/inject/module_inject.dart';

/// Todas las dependencias de la aplicación, módulo por módulo.
///
/// Es el único que se llama desde `main`, antes de `runApp`: agregar un módulo
/// es agregarlo a [modules] y nada más. Es a su vez un [ModuleInject], de modo
/// que una prueba lo puede usar igual que cualquier otro módulo.
///
/// Primero van los dos módulos que atraviesan la aplicación —lo que se guarda
/// en el equipo y la conexión a la base— y después uno por función. Ese orden
/// es para leerlo: como todo queda registrado de forma perezosa, nada se
/// construye durante el registro y las dependencias entre módulos —el
/// datasource de órdenes necesita el DAO de clientes, el de categorías el de
/// precios— se resuelven después, cuando ya pasaron todos.
class AppModule extends ModuleInject {
  const AppModule();

  static const modules = <ModuleInject>[
    SharedPreferencesModule(),
    DatabaseModule(),
    EmpresaModule(),
    ClientesModule(),
    CategoriasModule(),
    PreciosModule(),
    OrdenesModule(),
  ];

  @override
  Future<void> injectAll() async {
    for (final module in modules) {
      await module.injectAll();
    }
  }
}
