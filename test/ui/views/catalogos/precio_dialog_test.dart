import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/dialogs/precio_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// El formulario de un concepto: los precios van en una tabla, un renglón por
/// categoría elegida. Los días se heredan de cada categoría, y editar no se
/// los pisa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// Cuántos conceptos devolvió el diálogo al cerrarse, o `null`.
  int? resultado;

  Future<int> crearCategoria({
    required String nombre,
    required int diasEntrega,
  }) {
    return db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: Value(nombre),
        estatus: const Value(EstatusType.activo),
        diasEntrega: Value(diasEntrega),
      ),
    );
  }

  /// Abre el formulario como lo abre el listado —de alta si [precio] no
  /// viene— y espera a que lea las categorías.
  Future<void> abrirFormulario(
    WidgetTester tester, {
    PrecioData? precio,
    Size tamano = const Size(1000, 900),
  }) async {
    await tester.binding.setSurfaceSize(tamano);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<int>(
                    context: context,
                    builder: (context) => PrecioDialog(precio: precio),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump();

    await ProviderScope.containerOf(tester.element(find.byType(PrecioDialog)))
        .read(preciosViewModelProvider.notifier)
        .cargar();
    await tester.pumpAndSettle();
  }

  Future<void> tocarCategoria(WidgetTester tester, String nombre) async {
    await tester.tap(find.widgetWithText(FilterChip, nombre));
    await tester.pumpAndSettle();
  }

  Finder nombre() => find.ancestor(
    of: find.text('Nombre del concepto'),
    matching: find.byType(TextField),
  );

  /// Los campos del renglón de una categoría: van sin etiqueta, la dice el
  /// encabezado de la tabla.
  Finder importe(int categoriaId) => find.descendant(
    of: find.byKey(ValueKey('importe-$categoriaId')),
    matching: find.byType(TextField),
  );

  Finder dias(int categoriaId) => find.descendant(
    of: find.byKey(ValueKey('dias-$categoriaId')),
    matching: find.byType(TextField),
  );

  String textoDe(WidgetTester tester, Finder campo) =>
      tester.widget<TextField>(campo).controller?.text ?? '';

  Future<void> escribir(WidgetTester tester, Finder campo, String texto) async {
    await tester.enterText(campo, texto);
    await tester.pumpAndSettle();
  }

  Future<void> pulsar(WidgetTester tester, String boton) async {
    await tester.tap(find.widgetWithText(FilledButton, boton));
    await tester.pumpAndSettle();
  }

  Future<List<PrecioData>> guardados() =>
      instance<PreciosLocalDatasource>().activos();

  setUp(() async {
    resultado = null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  group('con una categoría', () {
    testWidgets('hereda sus días y el precio va en la tabla', (tester) async {
      final camaId = await crearCategoria(
        nombre: 'Ropa de cama',
        diasEntrega: 3,
      );

      await abrirFormulario(tester);

      // Sin categoría no hay precio que capturar todavía.
      expect(find.byType(Table), findsNothing);
      expect(
        find.text('Elige una categoría para ponerle precio.'),
        findsOneWidget,
      );

      await tocarCategoria(tester, 'Ropa de cama');

      expect(find.byType(Table), findsOneWidget);
      expect(textoDe(tester, dias(camaId)), '3');
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });

    testWidgets('cambiar de categoría trae los días de la nueva', (
      tester,
    ) async {
      await crearCategoria(nombre: 'Ropa de cama', diasEntrega: 3);
      final planchadoId = await crearCategoria(
        nombre: 'Planchado',
        diasEntrega: 7,
      );

      await abrirFormulario(tester);

      await tocarCategoria(tester, 'Ropa de cama');
      await tocarCategoria(tester, 'Ropa de cama');
      await tocarCategoria(tester, 'Planchado');

      expect(textoDe(tester, dias(planchadoId)), '7');
    });

    testWidgets('los días escritos a mano mandan sobre los de la categoría', (
      tester,
    ) async {
      final camaId = await crearCategoria(
        nombre: 'Ropa de cama',
        diasEntrega: 3,
      );

      await abrirFormulario(tester);
      await tocarCategoria(tester, 'Ropa de cama');
      await escribir(tester, dias(camaId), '5');

      expect(textoDe(tester, dias(camaId)), '5');
    });

    testWidgets('se guarda un concepto', (tester) async {
      final camaId = await crearCategoria(
        nombre: 'Ropa de cama',
        diasEntrega: 3,
      );

      await abrirFormulario(tester);
      await escribir(tester, nombre(), 'Sábana');
      await tocarCategoria(tester, 'Ropa de cama');
      await escribir(tester, importe(camaId), '50');
      await pulsar(tester, 'Guardar');

      expect(resultado, 1);
      final conceptos = await guardados();
      expect(conceptos.single.nombreConcepto, 'Sábana');
      expect(conceptos.single.categoria, 'Ropa de cama');
      expect(conceptos.single.importe, 50);
      expect(conceptos.single.diasEntrega, 3);
    });

    testWidgets('sin importe no se guarda y lo marca', (tester) async {
      await crearCategoria(nombre: 'Ropa de cama', diasEntrega: 3);

      await abrirFormulario(tester);
      await escribir(tester, nombre(), 'Sábana');
      await tocarCategoria(tester, 'Ropa de cama');
      await pulsar(tester, 'Guardar');

      expect(find.text('El importe debe ser mayor que cero'), findsOneWidget);
      expect(find.byType(PrecioDialog), findsOneWidget);
      expect(await guardados(), isEmpty);
    });
  });

  group('con varias categorías', () {
    late int lavadoId;
    late int planchadoId;
    late int tintoreriaId;

    Future<void> elegirTres(WidgetTester tester) async {
      lavadoId = await crearCategoria(nombre: 'Lavado', diasEntrega: 2);
      planchadoId = await crearCategoria(nombre: 'Planchado', diasEntrega: 1);
      tintoreriaId = await crearCategoria(nombre: 'Tintorería', diasEntrega: 5);

      await abrirFormulario(tester);
      await escribir(tester, nombre(), 'Playera');
      await tocarCategoria(tester, 'Lavado');
      await tocarCategoria(tester, 'Planchado');
      await tocarCategoria(tester, 'Tintorería');
    }

    testWidgets('un renglón rayado por categoría, y se guardan todos', (
      tester,
    ) async {
      await elegirTres(tester);

      // El encabezado y un renglón por categoría, con los días de cada una.
      final tabla = tester.widget<Table>(find.byType(Table));
      expect(tabla.children, hasLength(4));
      expect(textoDe(tester, dias(lavadoId)), '2');
      expect(textoDe(tester, dias(planchadoId)), '1');
      expect(textoDe(tester, dias(tintoreriaId)), '5');

      final colores = [
        for (final renglon in tabla.children.skip(1))
          (renglon.decoration! as BoxDecoration).color,
      ];
      expect(colores[0], isNot(colores[1]));
      expect(colores[0], colores[2]);

      await escribir(tester, importe(lavadoId), '30');
      await escribir(tester, importe(planchadoId), '20');
      await escribir(tester, importe(tintoreriaId), '80');

      await pulsar(tester, 'Guardar 3 conceptos');

      expect(resultado, 3);
      final conceptos = {
        for (final concepto in await guardados())
          concepto.categoria: (concepto.importe, concepto.diasEntrega),
      };
      expect(conceptos, {
        'Lavado': (30.0, 2),
        'Planchado': (20.0, 1),
        'Tintorería': (80.0, 5),
      });
    });

    testWidgets('marca el renglón al que le falta el importe', (tester) async {
      await elegirTres(tester);
      await escribir(tester, importe(lavadoId), '30');
      await escribir(tester, importe(tintoreriaId), '80');

      await pulsar(tester, 'Guardar 3 conceptos');

      final error = find.text('El importe debe ser mayor que cero');
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('importe-$planchadoId')),
          matching: error,
        ),
        findsOneWidget,
      );
      expect(await guardados(), isEmpty);
    });

    testWidgets('sin nombre no se guarda', (tester) async {
      final lavado = await crearCategoria(nombre: 'Lavado', diasEntrega: 2);
      final planchado = await crearCategoria(
        nombre: 'Planchado',
        diasEntrega: 1,
      );

      await abrirFormulario(tester);
      await tocarCategoria(tester, 'Lavado');
      await tocarCategoria(tester, 'Planchado');
      await escribir(tester, importe(lavado), '30');
      await escribir(tester, importe(planchado), '20');
      await pulsar(tester, 'Guardar 2 conceptos');

      expect(
        find.text('El nombre del concepto es obligatorio'),
        findsOneWidget,
      );
      expect(await guardados(), isEmpty);
    });

    testWidgets('se puede usar el importe de la primera en todas', (
      tester,
    ) async {
      await elegirTres(tester);

      // Sin importe en la primera no hay qué copiar.
      expect(find.textContaining('Usar el importe de'), findsNothing);

      await escribir(tester, importe(lavadoId), '30');
      await tester.tap(find.text(r'Usar el importe de Lavado ($30) en todas'));
      await tester.pumpAndSettle();

      expect(textoDe(tester, importe(planchadoId)), '30');
      expect(textoDe(tester, importe(tintoreriaId)), '30');
      // Los días no se copian: son de cada categoría.
      expect(textoDe(tester, dias(tintoreriaId)), '5');
      // Ya son iguales: el botón sobra.
      expect(find.textContaining('Usar el importe de'), findsNothing);
    });

    testWidgets('si uno ya existe, no se crea ninguno', (tester) async {
      final lavado = await crearCategoria(nombre: 'Lavado', diasEntrega: 2);
      final planchado = await crearCategoria(
        nombre: 'Planchado',
        diasEntrega: 1,
      );
      await instance<PreciosLocalDatasource>().guardar(
        PrecioData(
          categoriaId: lavado,
          categoria: 'Lavado',
          nombreConcepto: 'Playera',
          diasEntrega: 2,
          importe: 25,
        ),
      );

      await abrirFormulario(tester);
      await escribir(tester, nombre(), 'Playera');
      await tocarCategoria(tester, 'Planchado');
      await tocarCategoria(tester, 'Lavado');
      await escribir(tester, importe(planchado), '20');
      await escribir(tester, importe(lavado), '30');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar 2 conceptos'),
      );
      // El aviso de error lleva una animación que no se asienta.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Sólo sigue el que ya existía: Planchado no se quedó a medias.
      final conceptos = await guardados();
      expect(conceptos.map((c) => c.categoria), ['Lavado']);
      expect(resultado, isNull);
    });
  });

  testWidgets('editando, cambiar de categoría no pisa sus días', (
    tester,
  ) async {
    final categoriaId = await crearCategoria(
      nombre: 'Ropa de cama',
      diasEntrega: 3,
    );
    final planchadoId = await crearCategoria(
      nombre: 'Planchado',
      diasEntrega: 7,
    );

    // Un concepto con sus propios días, distintos de los de ambas
    // categorías: se pusieron a propósito y no hay que perderlos.
    await abrirFormulario(
      tester,
      precio: PrecioData(
        id: 1,
        categoriaId: categoriaId,
        categoria: 'Ropa de cama',
        nombreConcepto: 'Sábana',
        diasEntrega: 9,
        importe: 50,
      ),
    );

    expect(textoDe(tester, dias(categoriaId)), '9');

    await tocarCategoria(tester, 'Planchado');

    // Una sola categoría: elegir otra la cambia, no la suma.
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(2));
    expect(textoDe(tester, dias(planchadoId)), '9');
    expect(textoDe(tester, importe(planchadoId)), '50.00');
    expect(
      find.widgetWithText(FilledButton, 'Guardar cambios'),
      findsOneWidget,
    );
  });

  testWidgets('dos cambios seguidos, sin redibujar en medio, no se pisan', (
    tester,
  ) async {
    await crearCategoria(nombre: 'Lavado', diasEntrega: 2);
    await crearCategoria(nombre: 'Planchado', diasEntrega: 1);
    await abrirFormulario(tester);

    // Escribir y tocar dos categorías en el mismo cuadro: cada cambio se
    // aplica sobre el anterior, no sobre lo que había al dibujar.
    await tester.enterText(nombre(), 'Playera');
    await tester.tap(find.widgetWithText(FilterChip, 'Lavado'));
    await tester.tap(find.widgetWithText(FilterChip, 'Planchado'));
    await tester.pumpAndSettle();

    expect(textoDe(tester, nombre()), 'Playera');
    expect(
      find.widgetWithText(FilledButton, 'Guardar 2 conceptos'),
      findsOneWidget,
    );
  });

  testWidgets('cabe en ventanas chicas y grandes', (tester) async {
    await crearCategoria(nombre: 'Lavado', diasEntrega: 2);
    await crearCategoria(nombre: 'Planchado', diasEntrega: 1);
    await crearCategoria(nombre: 'Tintorería', diasEntrega: 5);

    for (final tamano in const [
      Size(1920, 1080),
      Size(1144, 643),
      Size(640, 800),
      Size(420, 760),
    ]) {
      await abrirFormulario(tester, tamano: tamano);
      await tocarCategoria(tester, 'Lavado');
      expect(tester.takeException(), isNull, reason: '$tamano · una');

      // Con los errores a la vista es cuando más crece cada renglón.
      await tocarCategoria(tester, 'Planchado');
      await tocarCategoria(tester, 'Tintorería');
      await pulsar(tester, 'Guardar 3 conceptos');
      expect(tester.takeException(), isNull, reason: '$tamano · errores');

      Navigator.of(tester.element(find.byType(PrecioDialog))).pop();
      await tester.pumpAndSettle();
    }
  });
}
