import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogo_pendiente.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ordenes_view.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/view_model/ordenes_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba la forma del módulo de órdenes: la tarjeta con el listado, el
/// encabezado con el alta, los filtros y lo que todavía está por portar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// Cuántos clientes se han creado, para que cada uno tenga su teléfono: la
  /// base no admite dos iguales.
  var creados = 0;

  Future<int> crearCliente({String nombres = 'Ana'}) {
    creados++;

    return db.clientesDao.insertCliente(
      ClienteCompanion(
        nombres: Value(nombres),
        apellidos: const Value('Pérez'),
        telefono: Value('55${creados.toString().padLeft(8, '0')}'),
        correo: Value('cliente$creados@correo.com'),
      ),
    );
  }

  /// Una orden con su primer movimiento, que es lo que la hace aparecer en el
  /// listado: la consulta une cada orden con el último que tenga.
  Future<String> crearOrden({
    required int clienteId,
    double total = 100,
    double restante = 0,
    EstatusOrdenType estatus = EstatusOrdenType.enCurso,
  }) async {
    final orden = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: estatus,
        total: total,
        restante: restante,
        fechaCreacion: DateTime.now(),
      ),
    );

    await db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: orden.id,
        monto: total - restante,
        restante: restante,
        metodoPago: MetodoPagoType.efectivo,
        fecha: orden.fechaCreacion,
      ),
    );

    return orden.folio;
  }

  /// Abre el módulo y espera a que el listado termine de leer.
  ///
  /// La lectura se espera llamando a la misma función que hace la pantalla, en
  /// lugar de bombear un rato: cuánto tarda depende de la máquina.
  Future<void> abrirModulo(
    WidgetTester tester, {
    Size tamano = const Size(1400, 900),
  }) async {
    await tester.binding.setSurfaceSize(tamano);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OrdenesView())),
      ),
    );
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(OrdenesView)),
    );

    await contenedor.read(ordenesViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  setUp(() async {
    creados = 0;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('la tarjeta ocupa el módulo entero', (tester) async {
    await abrirModulo(tester);

    final tarjeta = tester.getRect(find.byType(ListadoCard));

    expect(tarjeta.width, 1400);
    expect(tarjeta.height, 900);
  });

  testWidgets('cada orden es una fila con su folio y su cliente', (
    tester,
  ) async {
    final clienteId = await crearCliente(nombres: 'Lucía');
    final folio = await crearOrden(clienteId: clienteId, total: 250);

    await abrirModulo(tester);

    expect(find.text(folio), findsOneWidget);
    expect(find.text('Lucía Pérez'), findsOneWidget);
    expect(find.text('250.00'), findsOneWidget);
    expect(find.byType(EstatusOrdenChip), findsOneWidget);
  });

  testWidgets('sin órdenes lo dice en lugar de una tabla vacía', (
    tester,
  ) async {
    await abrirModulo(tester);

    expect(find.text('Todavía no hay órdenes registradas.'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('el encabezado lleva el módulo y el alta', (tester) async {
    await abrirModulo(tester);

    expect(find.text('Órdenes de servicio'), findsOneWidget);
    expect(find.widgetWithText(ButtonAdd, 'Nueva orden'), findsOneWidget);
  });

  testWidgets('los filtros del listado están todos en su renglón', (
    tester,
  ) async {
    await abrirModulo(tester);

    final filtros = find.byKey(DataTableCard.llaveFiltros);

    // Se buscan por tipo y no por su etiqueta: un `DropdownMenu` dibuja la
    // suya dos veces —una en el campo y otra escondida, con la que se mide—,
    // así que buscarla por texto no distingue un filtro de ninguno.
    final esperados = <String, Finder>{
      'el buscador': find.byType(SearchFilter),
      'el estatus': find.byType(FiltroEstatusOrden),
      'el método de pago': find.byType(FiltroMetodoPago),
      'las fechas de creación': find.byType(DateRangePicker),
      'el ordenamiento': find.byType(SortDropdown<ColumnsOrdenesNames>),
      'el botón de limpiar': find.byType(ButtonClearFilters),
    };

    for (final MapEntry(key: nombre, value: filtro) in esperados.entries) {
      expect(
        find.descendant(of: filtros, matching: filtro),
        findsOneWidget,
        reason: 'falta $nombre',
      );
    }
  });

  testWidgets('el buscador acota la tabla', (tester) async {
    final ana = await crearCliente(nombres: 'Ana');
    final beto = await crearCliente(nombres: 'Beto');
    final deAna = await crearOrden(clienteId: ana);
    final deBeto = await crearOrden(clienteId: beto);

    await abrirModulo(tester);

    await tester.enterText(
      find.ancestor(
        of: find.text('Buscar por folio o cliente'),
        matching: find.byType(TextField),
      ),
      'Beto',
    );

    // El buscador espera a que se deje de escribir antes de avisar.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(deBeto), findsOneWidget);
    expect(find.text(deAna), findsNothing);
  });

  group('lo que todavía está por portar', () {
    testWidgets('el alta avisa en lugar de abrir el formulario', (
      tester,
    ) async {
      await abrirModulo(tester);

      await tester.tap(find.widgetWithText(ButtonAdd, 'Nueva orden'));
      await tester.pumpAndSettle();

      expect(find.byType(DialogoPendiente), findsOneWidget);
      expect(find.text('Nueva orden de servicio'), findsOneWidget);
    });

    testWidgets('las acciones de la orden avisan y dicen cuál es', (
      tester,
    ) async {
      final clienteId = await crearCliente(nombres: 'Lucía');
      final folio = await crearOrden(clienteId: clienteId);

      await abrirModulo(tester);

      // Son tres acciones, así que la tabla las agrupa en un menú.
      await tester.tap(find.byType(PopupMenuButton<TableAction>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver historial de la orden'));
      await tester.pumpAndSettle();

      expect(find.byType(DialogoPendiente), findsOneWidget);
      expect(find.text('Orden $folio · Lucía Pérez'), findsOneWidget);
    });
  });
}
