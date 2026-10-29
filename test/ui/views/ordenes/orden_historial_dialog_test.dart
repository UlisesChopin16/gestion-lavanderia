import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/orden_historial_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/view_model/orden_historial_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba que el historial cuenta la orden en el orden en que pasó: el
/// alta arriba, cada visita con lo que pagó y se llevó, y al final lo que
/// falta o cómo se cerró.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  group('la línea de tiempo', () {
    const sabana = PrecioData(
      categoriaId: 1,
      categoria: 'Ropa de cama',
      nombreConcepto: 'Sábana',
    );

    MovimientoData movimiento(
      int id,
      DateTime fecha, {
      double monto = 0,
      bool entrega = false,
    }) {
      return MovimientoData(
        id: id,
        monto: monto,
        fecha: fecha,
        entregados: [
          if (entrega)
            ItemOrdenData(
              precio: sabana,
              fechaEntrega: fecha,
              ordenHistoryId: id,
            ),
        ],
      );
    }

    OrdenHistorialState conHistorial(List<MovimientoData> historial) {
      return OrdenHistorialState(
        cargando: false,
        orden: OrdenDetalleData(
          id: 1,
          folio: '2610-0001',
          clienteId: 1,
          cliente: 'Lucía Pérez',
          estatus: EstatusOrdenType.enCurso,
          total: 100,
          restante: 0,
          fechaCreacion: DateTime(2026, 10, 20, 9),
          historial: historial,
        ),
      );
    }

    test('va de lo último al alta, agrupado por día', () {
      // Como lo entrega la base: el más reciente primero.
      final estado = conHistorial([
        movimiento(4, DateTime(2026, 10, 23, 18), monto: 30, entrega: true),
        movimiento(3, DateTime(2026, 10, 21, 17), entrega: true),
        movimiento(2, DateTime(2026, 10, 21, 11), monto: 50),
        movimiento(1, DateTime(2026, 10, 20, 9), monto: 20),
      ]);

      final dias = estado.dias;

      expect(dias.map((dia) => dia.dia), [
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 20),
      ]);
      expect(
        [
          for (final dia in dias)
            for (final evento in dia.eventos) evento.movimiento.id,
        ],
        [4, 3, 2, 1],
      );
      expect(
        [
          for (final dia in dias)
            for (final evento in dia.eventos) evento.tipo,
        ],
        [
          TipoMovimientoType.pagoYEntrega,
          TipoMovimientoType.entrega,
          TipoMovimientoType.pago,
          TipoMovimientoType.adelanto,
        ],
      );
    });

    test('sólo el más antiguo es el alta', () {
      final estado = conHistorial([
        movimiento(2, DateTime(2026, 10, 21, 11), monto: 50),
        movimiento(1, DateTime(2026, 10, 20, 9), monto: 20),
      ]);

      final eventos = estado.dias.expand((dia) => dia.eventos).toList();

      // Los dos cobran, pero sólo el de hasta abajo es el adelanto.
      expect(eventos.first.movimiento.id, 2);
      expect(eventos.first.tipo, TipoMovimientoType.pago);
      expect(eventos.last.tipo, TipoMovimientoType.adelanto);
    });

    test('sin orden no hay días', () {
      expect(const OrdenHistorialState().dias, isEmpty);
    });
  });

  group('el diálogo', () {
    late AppDatabase db;
    late int clienteId;
    late List<PrecioData> catalogo;

    OrdenesLocalDatasource ordenes() => instance<OrdenesLocalDatasource>();

    /// Una orden con una sábana (50) y una cobija (120): 170 en total.
    Future<OrdenDetalleData> crearOrden({double abono = 0}) {
      return ordenes().crearOrden(
        clienteId: clienteId,
        items: [
          for (final precio in catalogo)
            ItemOrdenData(precio: precio, fechaEntrega: DateTime(2026, 10, 25)),
        ],
        abono: abono,
      );
    }

    ItemOrdenData item(OrdenDetalleData orden, String concepto) =>
        orden.items.firstWhere((item) => item.concepto == concepto);

    /// Abre el historial como lo abre el listado y espera a que lo lea.
    Future<void> abrirHistorial(
      WidgetTester tester,
      int ordenId, {
      Size tamano = const Size(1400, 900),
    }) async {
      await tester.binding.setSurfaceSize(tamano);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            // Con la densidad de escritorio, que es donde corre la aplicación.
            theme: ThemeData(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) =>
                        OrdenHistorialDialog(ordenId: ordenId),
                  ),
                  child: const Text('Ver'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ver'));
      await tester.pump();

      await ProviderScope.containerOf(
        tester.element(find.byType(OrdenHistorialDialog)),
      ).read(ordenHistorialViewModelProvider(ordenId).notifier).cargar();
      await tester.pumpAndSettle();
    }

    /// Dónde quedó un texto, para comparar quién va arriba de quién.
    double alturaDe(WidgetTester tester, String texto) =>
        tester.getTopLeft(find.text(texto)).dy;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await registrarDependenciasDePrueba(db: db);

      clienteId = await db.clientesDao.insertCliente(
        const ClienteCompanion(
          nombres: Value('Lucía'),
          apellidos: Value('Pérez'),
          telefono: Value('5559998888'),
          correo: Value('lucia@correo.com'),
        ),
      );

      final categoriaId = await db.categoriaServicioDao.insertCategoria(
        const CategoriaServicioCompanion(
          nombre: Value('Ropa de cama'),
          estatus: Value(EstatusType.activo),
          diasEntrega: Value(2),
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

      catalogo = await instance<PreciosLocalDatasource>().activos();
    });

    tearDown(() async {
      await limpiarDependenciasDePrueba();
      await db.close();
    });

    testWidgets('cuenta la orden del cierre al adelanto', (tester) async {
      final orden = await crearOrden(abono: 20);
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        monto: 30,
        metodoPago: MetodoPagoType.tarjeta,
        itemsAEntregar: [item(orden, 'Sábana').id],
      );
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        monto: 120,
        recibido: 200,
        itemsAEntregar: [item(orden, 'Cobija').id],
      );

      await abrirHistorial(tester, orden.id);

      expect(find.text('Historial · Orden ${orden.folio}'), findsOneWidget);
      expect(find.text('3 registros'), findsOneWidget);

      // De lo último al alta: el cierre arriba y el adelanto hasta abajo.
      expect(find.text('Adelanto'), findsOneWidget);
      expect(find.text('Pago y entrega'), findsNWidgets(2));
      expect(find.text('Orden cerrada'), findsOneWidget);
      expect(
        alturaDe(tester, 'Orden cerrada'),
        lessThan(alturaDe(tester, 'Adelanto')),
      );

      // Lo que se cobró en cada uno, con qué y lo que quedó.
      expect(find.text('+ 20.00'), findsOneWidget);
      expect(find.text('Quedó a deber 150.00'), findsOneWidget);
      expect(find.text('+ 30.00'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Quedó a deber 120.00'), findsOneWidget);
      expect(find.text('+ 120.00'), findsOneWidget);
      expect(find.textContaining('Cambio 80.00'), findsOneWidget);
      expect(find.text('Con esto quedó pagada'), findsOneWidget);

      // Y lo que se llevó en cada visita: la cobija salió después, así que
      // va más arriba.
      expect(find.text('Sábana'), findsOneWidget);
      expect(find.text('Cobija'), findsOneWidget);
      expect(alturaDe(tester, 'Cobija'), lessThan(alturaDe(tester, 'Sábana')));

      // Los medidores, llenos.
      expect(find.text('Pagada por completo'), findsOneWidget);
      expect(find.text('Toda la ropa salió'), findsOneWidget);
    });

    testWidgets('abierta, empieza por lo que falta', (tester) async {
      final orden = await crearOrden(abono: 20);
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        itemsAEntregar: [item(orden, 'Sábana').id],
      );

      await abrirHistorial(tester, orden.id);

      expect(find.text('Entrega'), findsOneWidget);
      expect(find.text('Lo que falta'), findsOneWidget);
      expect(find.text('Falta entregar 1 concepto'), findsNWidgets(2));
      expect(find.text('Queda a deber 150.00'), findsOneWidget);

      // Lo que falta va arriba de todo, con la cobija pendiente dentro, y
      // debajo los movimientos: la entrega de hoy antes que el adelanto.
      expect(
        alturaDe(tester, 'Lo que falta'),
        lessThan(alturaDe(tester, 'Cobija')),
      );
      expect(alturaDe(tester, 'Cobija'), lessThan(alturaDe(tester, 'Entrega')));
      expect(
        alturaDe(tester, 'Entrega'),
        lessThan(alturaDe(tester, 'Adelanto')),
      );
      expect(find.textContaining('era para el'), findsOneWidget);
      expect(find.text('Orden cerrada'), findsNothing);
    });

    testWidgets('lo entregado va en cuadrícula, debajo del cobro', (
      tester,
    ) async {
      final orden = await crearOrden();
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        monto: 170,
        itemsAEntregar: orden.items.map((i) => i.id),
      );

      await abrirHistorial(tester, orden.id);

      // Las dos prendas en el mismo renglón, una junto a la otra.
      final sabana = tester.getTopLeft(find.text('Sábana'));
      final cobija = tester.getTopLeft(find.text('Cobija'));
      expect(cobija.dy, sabana.dy);
      expect(cobija.dx, greaterThan(sabana.dx));

      // La tarjeta sigue apilada: el cobro arriba, la ropa y luego el saldo.
      expect(alturaDe(tester, '+ 170.00'), lessThan(sabana.dy));
      expect(sabana.dy, lessThan(alturaDe(tester, 'Con esto quedó pagada')));
    });

    testWidgets('angosto, la cuadrícula queda en una columna', (tester) async {
      final orden = await crearOrden();

      await abrirHistorial(tester, orden.id, tamano: const Size(420, 760));

      final sabana = tester.getTopLeft(find.text('Sábana'));
      final cobija = tester.getTopLeft(find.text('Cobija'));
      expect(cobija.dx, sabana.dx);
      expect(cobija.dy, greaterThan(sabana.dy));
    });

    testWidgets('lo que falta acomoda la ropa en columnas', (tester) async {
      final orden = await crearOrden();

      await abrirHistorial(tester, orden.id);

      // Las dos prendas pendientes en el mismo renglón, una junto a la otra.
      final sabana = tester.getTopLeft(find.text('Sábana'));
      final cobija = tester.getTopLeft(find.text('Cobija'));
      expect(cobija.dy, sabana.dy);
      expect(cobija.dx, greaterThan(sabana.dx));
    });

    testWidgets('sin adelanto, el alta lo dice', (tester) async {
      final orden = await crearOrden();

      await abrirHistorial(tester, orden.id);

      expect(find.text('Alta de la orden'), findsOneWidget);
      expect(find.text('Se recibió la ropa sin adelanto'), findsOneWidget);
      expect(find.text('Quedó a deber 170.00'), findsOneWidget);
      // El día va en un texto con dos estilos: "Hoy · martes 28 de …".
      expect(find.textContaining('Hoy · ', findRichText: true), findsOneWidget);
    });

    testWidgets('pagar justo no enseña cambio', (tester) async {
      final orden = await crearOrden();
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        monto: 170,
        recibido: 170,
      );

      await abrirHistorial(tester, orden.id);

      expect(find.text('Pagó justo'), findsOneWidget);
      expect(find.textContaining('Cambio'), findsNothing);
    });

    testWidgets('cabe en ventanas chicas y grandes', (tester) async {
      final orden = await crearOrden(abono: 20);
      await ordenes().registrarMovimiento(
        ordenId: orden.id,
        monto: 30,
        recibido: 100,
        itemsAEntregar: [item(orden, 'Sábana').id],
      );

      for (final tamano in const [
        Size(1920, 1080),
        Size(1144, 643),
        Size(900, 700),
        Size(640, 800),
        Size(420, 760),
      ]) {
        await abrirHistorial(tester, orden.id, tamano: tamano);

        expect(tester.takeException(), isNull, reason: '$tamano');
        expect(find.byType(OrdenHistorialDialog), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Cerrar'));
        await tester.pumpAndSettle();
      }
    });
  });
}
