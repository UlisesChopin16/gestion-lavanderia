import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/app_module.dart';
import 'package:gestion_lavanderia/services/logo_storage.dart';

import '../support/inyeccion_de_prueba.dart';

/// Que el grafo de dependencias se pueda armar completo.
///
/// Cada módulo registra lo de su función, y hay dependencias que lo cruzan: el
/// datasource de órdenes necesita el DAO de clientes y el de categorías el de
/// precios. Resolver cada pieza es lo único que comprueba que ningún módulo se
/// quedó fuera de `AppModule.modules`, porque al ser perezosas nada falla hasta
/// que alguien las pide —y entonces falla en pantalla—.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  test('todos los datasources se resuelven', () {
    expect(instance<CategoriasLocalDatasource>(), isNotNull);
    expect(instance<ClientesLocalDatasource>(), isNotNull);
    expect(instance<EmpresaLocalDatasource>(), isNotNull);
    expect(instance<OrdenesLocalDatasource>(), isNotNull);
    expect(instance<PreciosLocalDatasource>(), isNotNull);
  });

  test('los filtros guardados y los servicios se resuelven', () {
    expect(instance<FiltrosStore>(), isNotNull);
    expect(instance<LogoStorage>(), isNotNull);
  });

  test('cada dependencia se construye una sola vez', () {
    // Son `lazySingleton`: dos pantallas que pidan el mismo datasource tienen
    // que recibir la misma instancia, y sobre todo la misma conexión a la base.
    expect(
      instance<EmpresaLocalDatasource>(),
      same(instance<EmpresaLocalDatasource>()),
    );
    expect(instance<AppDatabase>(), same(db));
  });

  test('registrar los módulos no construye nada', () async {
    // Un módulo que resolviera algo al registrarlo abriría la base de verdad
    // al arrancar, aunque no se visite ninguna pantalla que la use. Aquí se
    // nota porque la base no está reemplazada todavía: si el registro la
    // construyera, buscaría el archivo en el disco y la prueba fallaría.
    await instance.reset();

    await expectLater(const AppModule().injectAll(), completes);

    expect(instance.isRegistered<AppDatabase>(), isTrue);
    expect(instance.isRegistered<OrdenesLocalDatasource>(), isTrue);
  });
}
