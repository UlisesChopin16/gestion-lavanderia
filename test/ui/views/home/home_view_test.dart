import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/shared/views/pantalla_pendiente.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/configuracion_empresa_view.dart';
import 'package:gestion_lavanderia/ui/views/home/widgets/widgets.dart';
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

      expect(find.byType(BarraModulos), findsOneWidget);
      expect(find.text('Órdenes'), findsWidgets);
      expect(find.text('Catálogos'), findsWidgets);
      expect(find.text('Empresa'), findsWidgets);
      expect(find.byType(PantallaPendiente), findsOneWidget);
    });

    testWidgets('en una ventana angosta el menú pasa a un cajón', (
      tester,
    ) async {
      await conVentanaDe(tester, const Size(500, 800));

      await abrirAplicacion(tester);

      // La barra de módulos desaparece y queda la del nombre del módulo
      // abierto, con el cajón detrás del botón.
      expect(find.byType(BarraModulos), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Órdenes'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('el cajón abre el módulo elegido y se cierra', (tester) async {
      await conVentanaDe(tester, const Size(500, 800));

      await abrirAplicacion(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Empresa'));
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(ConfiguracionEmpresaView), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Empresa'), findsOneWidget);
    });
  });

  group('la barra de módulos', () {
    testWidgets('nombra los módulos sin iconos', (tester) async {
      await abrirAplicacion(tester);

      final boton = find.widgetWithText(BotonModulo, 'Empresa');

      expect(boton, findsOneWidget);
      expect(
        find.descendant(of: boton, matching: find.byType(Icon)),
        findsNothing,
      );
    });

    testWidgets('los tres módulos van en un renglón, arriba del contenido', (
      tester,
    ) async {
      await abrirAplicacion(tester);

      final ordenes = tester.getRect(
        find.widgetWithText(BotonModulo, 'Órdenes'),
      );
      final empresa = tester.getRect(
        find.widgetWithText(BotonModulo, 'Empresa'),
      );

      expect(empresa.top, ordenes.top);
      expect(empresa.left, greaterThan(ordenes.right));
      expect(
        ordenes.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(PantallaPendiente)).top),
      );
    });

    testWidgets('ilumina el botón entero del módulo abierto', (tester) async {
      await abrirAplicacion(tester);
      await abrirPestana(tester, 'Empresa');

      final scheme = Theme.of(tester.element(find.byType(BarraModulos)))
          .colorScheme;

      Material superficieDe(String titulo) => tester.widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(BotonModulo, titulo),
              matching: find.byType(Material),
            )
            .first,
      );

      // El realce cubre el botón, que es el que contiene también el texto.
      expect(
        superficieDe('Empresa').color,
        scheme.primary.withValues(alpha: 0.2),
      );
      expect(superficieDe('Órdenes').color, Colors.transparent);
    });
  });

  group('el módulo abierto', () {
    testWidgets('ocupa el ancho entero de la ventana', (tester) async {
      await conVentanaDe(tester, const Size(1000, 800));

      await abrirAplicacion(tester);

      // Con la navegación arriba ya no hay menú que le coma ancho: era lo que
      // se buscaba al subirla.
      expect(tester.getSize(find.byType(PantallaPendiente)).width, 1000);
    });

    testWidgets('ocupa todo el alto que deja la barra', (tester) async {
      await conVentanaDe(tester, const Size(1000, 800));

      await abrirAplicacion(tester);

      expect(
        tester.getSize(find.byType(PantallaPendiente)).height,
        800 - BarraModulos.alto,
      );
    });

    testWidgets('con el cajón escondido ocupa el ancho completo', (
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
