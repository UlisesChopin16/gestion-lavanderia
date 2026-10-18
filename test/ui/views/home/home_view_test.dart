import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/shared/views/pantalla_pendiente.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/configuracion_empresa_view.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/app_de_prueba.dart';
import '../../../support/inyeccion_de_prueba.dart';

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

  /// Cambia el tamaño de la ventana para el caso que lo necesite.
  Future<void> conVentanaDe(WidgetTester tester, Size tamano) async {
    await tester.binding.setSurfaceSize(tamano);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> abrirPestana(WidgetTester tester, String titulo) async {
    await tester.tap(find.text(titulo).last);
    await tester.pumpAndSettle();
  }

  group('la navegación', () {
    testWidgets('abre en órdenes y ofrece los tres módulos', (tester) async {
      await abrirAplicacion(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Órdenes'), findsWidgets);
      expect(find.text('Catálogos'), findsWidgets);
      expect(find.text('Empresa'), findsWidgets);
      expect(find.byType(PantallaPendiente), findsOneWidget);
    });

    testWidgets('en una ventana angosta baja a una barra inferior', (
      tester,
    ) async {
      await conVentanaDe(tester, const Size(500, 800));

      await abrirAplicacion(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('en una ventana ancha el riel se extiende', (tester) async {
      await conVentanaDe(tester, const Size(1400, 900));

      await abrirAplicacion(tester);

      final riel = tester.widget<NavigationRail>(find.byType(NavigationRail));

      expect(riel.extended, isTrue);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('el módulo abierto', () {
    testWidgets('ocupa todo el ancho que deja el riel', (tester) async {
      await conVentanaDe(tester, const Size(1000, 800));

      await abrirAplicacion(tester);

      final anchoRiel = tester.getSize(find.byType(NavigationRail)).width;
      final anchoModulo = tester.getSize(find.byType(PantallaPendiente)).width;

      // 1 es el divisor vertical entre el riel y el contenido.
      expect(anchoModulo, 1000 - anchoRiel - 1);
    });

    testWidgets('ocupa todo el alto disponible', (tester) async {
      await conVentanaDe(tester, const Size(1000, 800));

      await abrirAplicacion(tester);

      expect(tester.getSize(find.byType(PantallaPendiente)).height, 800);
    });

    testWidgets('con la barra inferior ocupa el ancho completo', (
      tester,
    ) async {
      await conVentanaDe(tester, const Size(500, 800));

      await abrirAplicacion(tester);

      expect(tester.getSize(find.byType(PantallaPendiente)).width, 500);
    });
  });

  group('las pestañas', () {
    testWidgets('no se construyen hasta que se visitan', (tester) async {
      await abrirAplicacion(tester);

      // La configuración de la empresa no está en el árbol todavía: si lo
      // estuviera, cada módulo abriría su consulta a la base al arrancar.
      expect(find.byType(ConfiguracionEmpresaView), findsNothing);

      await abrirPestana(tester, 'Empresa');

      expect(find.byType(ConfiguracionEmpresaView), findsOneWidget);
    });

    testWidgets('conservan lo capturado al ir y volver', (tester) async {
      await abrirAplicacion(tester);
      await abrirPestana(tester, 'Empresa');

      final campo = find.ancestor(
        of: find.text('Nombre de la empresa'),
        matching: find.byType(TextField),
      );
      await tester.enterText(campo, 'Lavandería El Sol');
      await tester.pumpAndSettle();

      await abrirPestana(tester, 'Órdenes');
      await abrirPestana(tester, 'Empresa');

      expect(
        tester.widget<TextField>(campo).controller?.text,
        'Lavandería El Sol',
      );
    });
  });

  group('el botón del tema', () {
    testWidgets('avanza entre los tres modos y lo dice en el globo', (
      tester,
    ) async {
      await abrirAplicacion(tester);

      Finder botonConTema(String modo) => find.byTooltip('Tema: $modo');

      expect(botonConTema('Según el sistema'), findsOneWidget);

      await tester.tap(botonConTema('Según el sistema'));
      await tester.pumpAndSettle();

      expect(botonConTema('Claro'), findsOneWidget);

      await tester.tap(botonConTema('Claro'));
      await tester.pumpAndSettle();

      expect(botonConTema('Oscuro'), findsOneWidget);

      await tester.tap(botonConTema('Oscuro'));
      await tester.pumpAndSettle();

      expect(botonConTema('Según el sistema'), findsOneWidget);
    });
  });
}
