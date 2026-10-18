import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';
import 'package:gestion_lavanderia/ui/views/home/home_view.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import 'support/app_de_prueba.dart';
import 'support/inyeccion_de_prueba.dart';

/// Que la aplicación arranque: las dependencias resueltas, el tema armado y el
/// home en pantalla. Lo que hace cada módulo se prueba en su propio archivo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('arranca en el home', (tester) async {
    await abrirAplicacion(tester);

    expect(find.byType(HomeView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el tema sale del color de la empresa', (tester) async {
    // Sin configuración guardada, el color es el que trae `EmpresaData`.
    await abrirAplicacion(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(
      app.theme?.colorScheme,
      ColorScheme.fromSeed(seedColor: ColoresEmpresa.porOmision),
    );
  });
}
