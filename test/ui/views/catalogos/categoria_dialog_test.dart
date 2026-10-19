import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/dialogs/cambio_dias_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/dialogs/categoria_dialog.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba hasta dónde llega un cambio de días de entrega: la categoría
/// pregunta antes de arrastrar a sus conceptos, y respeta la respuesta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// Una categoría de [diasEntrega] días con un concepto de [diasConcepto].
  Future<CategoriaData> sembrar({
    int diasEntrega = 3,
    int diasConcepto = 2,
  }) async {
    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: const Value('Ropa de cama'),
        estatus: const Value(EstatusType.activo),
        diasEntrega: Value(diasEntrega),
      ),
    );

    await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion(
        categoriaId: Value(categoriaId),
        clotheSize: const Value(ClotheSizeType.emptySize),
        nombreConcepto: const Value('Sábana'),
        diasEntrega: Value(diasConcepto),
        tipoUnidad: const Value(UnitType.pieza),
        importe: const Value(50),
        estatus: const Value(EstatusType.activo),
      ),
    );

    return (await instance<CategoriasLocalDatasource>().porId(categoriaId))!;
  }

  /// Abre el formulario de [categoria] como lo abre el listado.
  Future<void> abrirFormulario(
    WidgetTester tester,
    CategoriaData categoria,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (context) => CategoriaDialog(categoria: categoria),
                ),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
  }

  Future<void> escribirDias(WidgetTester tester, String dias) async {
    await tester.enterText(
      find.ancestor(
        of: find.text('Días de entrega'),
        matching: find.byType(TextField),
      ),
      dias,
    );
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
  }

  /// Los días con los que quedaron la categoría [id] y su concepto en la
  /// base, que es lo único que dice si la propagación corrió o no.
  Future<(int categoria, int concepto)> diasGuardados(int id) async {
    final fila = (await db.categoriaServicioDao.getById(id))!;
    final concepto = (await db.preciosConceptosDao.getAll()).single.precio;

    return (fila.diasEntrega, concepto.diasEntrega);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('cambiar los días pregunta qué pasa con los conceptos', (
    tester,
  ) async {
    final categoria = await sembrar();

    await abrirFormulario(tester, categoria);
    await escribirDias(tester, '5');
    await guardar(tester);

    expect(find.byType(CambioDiasDialog), findsOneWidget);
    expect(
      find.text('"Ropa de cama" pasa de 3 días a 5 días.'),
      findsOneWidget,
    );
    expect(
      find.text('Tiene 1 concepto. ¿También cambia sus días?'),
      findsOneWidget,
    );
  });

  testWidgets('"Sí, cambiar también" se los cambia a los conceptos', (
    tester,
  ) async {
    final categoria = await sembrar();

    await abrirFormulario(tester, categoria);
    await escribirDias(tester, '5');
    await guardar(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sí, cambiar también'));
    await tester.pumpAndSettle();

    expect(await diasGuardados(categoria.id), (5, 5));
  });

  testWidgets('"Sólo la categoría" deja a los conceptos como estaban', (
    tester,
  ) async {
    final categoria = await sembrar();

    await abrirFormulario(tester, categoria);
    await escribirDias(tester, '5');
    await guardar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Sólo la categoría'));
    await tester.pumpAndSettle();

    expect(await diasGuardados(categoria.id), (5, 2));
  });

  testWidgets('"Cancelar" no guarda nada, ni el nombre', (tester) async {
    final categoria = await sembrar();

    await abrirFormulario(tester, categoria);

    await tester.enterText(
      find.ancestor(
        of: find.text('Nombre de la categoría'),
        matching: find.byType(TextField),
      ),
      'Blancos',
    );
    await escribirDias(tester, '5');
    await guardar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(await diasGuardados(categoria.id), (3, 2));
    expect(
      (await db.categoriaServicioDao.getById(categoria.id))!.nombre,
      'Ropa de cama',
    );
    expect(
      find.byType(CategoriaDialog),
      findsOneWidget,
      reason: 'el formulario se queda abierto para corregir o salir',
    );
  });

  testWidgets('cambiar sólo el nombre no pregunta nada', (tester) async {
    final categoria = await sembrar();

    await abrirFormulario(tester, categoria);

    await tester.enterText(
      find.ancestor(
        of: find.text('Nombre de la categoría'),
        matching: find.byType(TextField),
      ),
      'Blancos',
    );
    await guardar(tester);

    expect(find.byType(CambioDiasDialog), findsNothing);
    expect(
      (await db.categoriaServicioDao.getById(categoria.id))!.nombre,
      'Blancos',
    );
    expect(await diasGuardados(categoria.id), (3, 2));
  });
}
