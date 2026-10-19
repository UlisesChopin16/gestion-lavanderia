import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/dialogs/cliente_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/orden_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/view_model/orden_dialog_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba el alta de una orden tal como se captura: tocar un concepto para
/// agregarlo, buscar al cliente, cobrar y crear.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// Lo que el diálogo devolvió al cerrarse.
  bool? resultado;

  Future<void> sembrarCatalogo() async {
    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: const Value('Ropa de cama'),
        estatus: const Value(EstatusType.activo),
        diasEntrega: const Value(2),
      ),
    );

    for (final (nombre, importe) in [('Sábana', 50.0), ('Cobija', 120.0)]) {
      await db.preciosConceptosDao.insertPrecio(
        PreciosConceptosCompanion(
          categoriaId: Value(categoriaId),
          clotheSize: const Value(ClotheSizeType.emptySize),
          nombreConcepto: Value(nombre),
          diasEntrega: const Value(2),
          tipoUnidad: const Value(UnitType.pieza),
          importe: Value(importe),
          estatus: const Value(EstatusType.activo),
        ),
      );
    }
  }

  Future<void> sembrarCliente({String nombres = 'Lucía'}) {
    return db.clientesDao.insertCliente(
      ClienteCompanion(
        nombres: Value(nombres),
        apellidos: const Value('Pérez'),
        telefono: const Value('5559998888'),
        correo: const Value('lucia@correo.com'),
      ),
    );
  }

  /// Abre el diálogo como lo abre el listado y espera a que lea el catálogo.
  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<bool>(
                    context: context,
                    builder: (context) => const OrdenDialog(),
                  );
                },
                child: const Text('Nueva orden'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Nueva orden'));
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(OrdenDialog)),
    );

    await contenedor.read(ordenDialogViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  /// Escribe en el buscador que lleva [etiqueta] y espera a que avise.
  Future<void> buscar(
    WidgetTester tester,
    String etiqueta,
    String texto,
  ) async {
    await tester.enterText(
      find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField)),
      texto,
    );

    // El buscador espera a que se deje de escribir antes de avisar.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    resultado = null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('el catálogo muestra el concepto con lo que hace falta', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    // Nombre, categoría, días de entrega, unidad y precio, todo en el mismo
    // renglón: es lo que hace falta para elegir sin abrir nada.
    final sabana = find.ancestor(
      of: find.text('Sábana'),
      matching: find.byType(ListTile),
    );

    expect(sabana, findsOneWidget);
    expect(
      find.descendant(
        of: sabana,
        matching: find.text('Ropa de cama · 2 días · Pieza'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sabana, matching: find.text('50.00')),
      findsOneWidget,
    );
  });

  testWidgets('sin cliente ni ropa no se puede crear', (tester) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    final crear = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear orden · 0.00'),
    );

    expect(crear.onPressed, isNull);
  });

  testWidgets('cuando el cliente no existe ofrece registrarlo', (tester) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(tester, 'Buscar por nombre, teléfono o correo', 'Lucía');

    expect(find.text('Nadie coincide con "Lucía".'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Registrar'), findsOneWidget);
  });

  testWidgets('registrar al cliente llega con lo tecleado ya repartido', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(
      tester,
      'Buscar por nombre, teléfono o correo',
      'Ulises Shie Sotelo Chopin',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    // El alta nace con el nombre repartido: lo que se escribió para buscar no
    // se vuelve a escribir.
    expect(find.byType(ClienteDialog), findsOneWidget);
    expect(find.text('Ulises Shie'), findsOneWidget);
    expect(find.text('Sotelo Chopin'), findsOneWidget);
  });

  testWidgets('buscar por teléfono registra con el teléfono puesto', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(tester, 'Buscar por nombre, teléfono o correo', '5559998888');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    // Un teléfono no es un nombre: va al campo que le toca.
    expect(find.text('5559998888'), findsWidgets);
    expect(
      tester
          .widget<TextField>(
            find.ancestor(
              of: find.text('Nombre(s)'),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('se arma la orden tocando el concepto y se crea', (tester) async {
    await sembrarCatalogo();
    await sembrarCliente();

    await abrirDialogo(tester);

    // Dos toques sobre el mismo concepto son dos sábanas.
    await tester.tap(find.text('Sábana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sábana').first);
    await tester.pumpAndSettle();

    // El cliente se busca por teléfono y se elige de la lista.
    await buscar(tester, 'Buscar por nombre, teléfono o correo', '5559998888');
    await tester.tap(find.text('Lucía Pérez'));
    await tester.pumpAndSettle();

    // Paga todo con el atajo.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todo'));
    await tester.pumpAndSettle();

    expect(find.text('Pagada'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Crear orden · 100.00'));
    await tester.pumpAndSettle();

    // El diálogo se cierra diciendo que guardó, y la orden está en la base.
    expect(resultado, isTrue);
    expect(find.byType(OrdenDialog), findsNothing);

    final ordenes = await instance<OrdenesLocalDatasource>().listado();
    final orden = ordenes.single;

    expect(orden.cliente, 'Lucía Pérez');
    expect(orden.total, 100);
    expect(orden.restante, 0);
    expect(orden.estatus, EstatusOrdenType.pagado);
  });
}
