import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/dialogs/precio_dialog.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba que un concepto nuevo hereda los días de entrega de su categoría
/// —que es lo que casi siempre corresponde— y que editarlo no se los pisa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

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

  /// Abre el formulario —de alta si [precio] no viene— con el catálogo ya
  /// leído, que es de donde salen las categorías que ofrece.
  Future<void> abrirFormulario(
    WidgetTester tester, {
    PrecioData? precio,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PrecioDialog(precio: precio)),
        ),
      ),
    );
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PrecioDialog)),
    );

    await contenedor.read(preciosViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  /// Elige [nombre] en el desplegable de categorías.
  Future<void> elegirCategoria(WidgetTester tester, String nombre) async {
    await tester.tap(
      find.ancestor(
        of: find.text('Categoría'),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();

    // La opción del menú desplegado: `DropdownMenu` arma además una copia
    // escondida con la que se mide, así que se toma la que se está viendo.
    await tester.tap(find.widgetWithText(MenuItemButton, nombre).last);
    await tester.pumpAndSettle();
  }

  /// Lo que dice el campo que lleva [etiqueta].
  String textoDe(WidgetTester tester, String etiqueta) {
    final campo = find.ancestor(
      of: find.text(etiqueta),
      matching: find.byType(TextField),
    );

    return tester.widget<TextField>(campo).controller?.text ?? '';
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('un concepto nuevo hereda los días de su categoría', (
    tester,
  ) async {
    await crearCategoria(nombre: 'Ropa de cama', diasEntrega: 3);

    await abrirFormulario(tester);

    expect(
      textoDe(tester, 'Días de entrega'),
      isEmpty,
      reason: 'sin categoría elegida no hay días que heredar',
    );

    await elegirCategoria(tester, 'Ropa de cama');

    expect(textoDe(tester, 'Días de entrega'), '3');
  });

  testWidgets('cambiar de categoría en un alta trae los días de la nueva', (
    tester,
  ) async {
    await crearCategoria(nombre: 'Ropa de cama', diasEntrega: 3);
    await crearCategoria(nombre: 'Planchado', diasEntrega: 7);

    await abrirFormulario(tester);

    await elegirCategoria(tester, 'Ropa de cama');
    await elegirCategoria(tester, 'Planchado');

    expect(textoDe(tester, 'Días de entrega'), '7');
  });

  testWidgets('los días escritos a mano mandan sobre los de la categoría', (
    tester,
  ) async {
    await crearCategoria(nombre: 'Ropa de cama', diasEntrega: 3);

    await abrirFormulario(tester);
    await elegirCategoria(tester, 'Ropa de cama');

    await tester.enterText(
      find.ancestor(
        of: find.text('Días de entrega'),
        matching: find.byType(TextField),
      ),
      '5',
    );
    await tester.pumpAndSettle();

    expect(textoDe(tester, 'Días de entrega'), '5');
  });

  testWidgets('editando un concepto, cambiar de categoría no pisa sus días', (
    tester,
  ) async {
    final categoriaId = await crearCategoria(
      nombre: 'Ropa de cama',
      diasEntrega: 3,
    );
    await crearCategoria(nombre: 'Planchado', diasEntrega: 7);

    // Un concepto que ya tenía sus propios días, distintos de los de ambas
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

    expect(textoDe(tester, 'Días de entrega'), '9');

    await elegirCategoria(tester, 'Planchado');

    expect(textoDe(tester, 'Días de entrega'), '9');
  });
}
