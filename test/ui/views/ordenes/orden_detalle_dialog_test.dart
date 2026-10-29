import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/orden_detalle_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/view_model/orden_detalle_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba lo que enseña el detalle según lo que le queda a la orden: el
/// cobro mientras debe, sólo la entrega cuando ya está pagada, y un resumen
/// cuando ya no le queda nada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late int clienteId;
  late List<PrecioData> catalogo;

  /// Lo que el diálogo devolvió al cerrarse.
  String? resultado;

  OrdenesLocalDatasource ordenes() => instance<OrdenesLocalDatasource>();

  /// Una orden con una sábana (50) y una cobija (120): 170 en total.
  Future<OrdenDetalleData> crearOrden({double abono = 0}) {
    return ordenes().crearOrden(
      clienteId: clienteId,
      items: [
        for (final precio in catalogo)
          ItemOrdenData(precio: precio, fechaEntrega: DateTime(2026, 10, 25)),
      ],
      descripcion: 'La cobija tiene una mancha de café',
      abono: abono,
    );
  }

  /// Abre el detalle como lo abre el listado y espera a que lea la orden.
  Future<void> abrirDetalle(WidgetTester tester, int ordenId) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // Con la densidad de escritorio, que es donde corre la aplicación:
          // con la de omisión una fila puede salir cuadrada aquí y
          // descuadrada en la ventana de verdad.
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<String>(
                    context: context,
                    builder: (context) => OrdenDetalleDialog(ordenId: ordenId),
                  );
                },
                child: const Text('Ver'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ver'));
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(OrdenDetalleDialog)),
    );
    await contenedor
        .read(ordenDetalleViewModelProvider(ordenId).notifier)
        .cargar();
    await tester.pumpAndSettle();
  }

  /// La casilla del renglón que muestra [concepto]. Es la del renglón más
  /// cercano al nombre: los de afuera —las columnas del diálogo— también son
  /// filas y llevan todas las casillas dentro.
  Checkbox casilla(WidgetTester tester, String concepto) {
    return tester.widget<Checkbox>(
      find.descendant(
        of: find
            .ancestor(of: find.text(concepto), matching: find.byType(Row))
            .first,
        matching: find.byType(Checkbox),
      ),
    );
  }

  FilledButton botonPrincipal(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last);

  setUp(() async {
    resultado = null;
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

  testWidgets('enseña al cliente, la nota, la ropa y lo que debe', (
    tester,
  ) async {
    final orden = await crearOrden(abono: 20);

    await abrirDetalle(tester, orden.id);

    expect(find.text('Orden ${orden.folio}'), findsOneWidget);
    expect(find.text('Lucía Pérez'), findsOneWidget);
    expect(find.text('5559998888'), findsOneWidget);
    expect(find.text('La cobija tiene una mancha de café'), findsOneWidget);
    expect(find.text('Sábana'), findsOneWidget);
    expect(find.text('Cobija'), findsOneWidget);
    expect(find.text('0 de 2 entregadas'), findsOneWidget);

    expect(find.text('Queda a deber'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);

    // Debe, así que se cobra: método, cuánto paga y con cuánto paga.
    expect(find.byType(CobroDetalle), findsOneWidget);
    expect(find.text('A pagar'), findsOneWidget);
    expect(find.text('Recibe'), findsOneWidget);
  });

  testWidgets('lo ya entregado se ve marcado y no se puede tocar', (
    tester,
  ) async {
    final orden = await crearOrden();
    final sabana = orden.items.firstWhere((i) => i.concepto == 'Sábana');
    await ordenes().registrarMovimiento(
      ordenId: orden.id,
      itemsAEntregar: [sabana.id],
    );

    await abrirDetalle(tester, orden.id);

    expect(casilla(tester, 'Sábana').value, isTrue);
    expect(casilla(tester, 'Sábana').onChanged, isNull);

    expect(casilla(tester, 'Cobija').value, isFalse);
    expect(casilla(tester, 'Cobija').onChanged, isNotNull);

    expect(find.text('1 de 2 entregadas'), findsOneWidget);
  });

  testWidgets('en efectivo dice cuánto cambio dar', (tester) async {
    final orden = await crearOrden();

    await abrirDetalle(tester, orden.id);

    await tester.enterText(
      find.ancestor(of: find.text('A pagar'), matching: find.byType(TextField)),
      '170',
    );
    await tester.enterText(
      find.ancestor(of: find.text('Recibe'), matching: find.byType(TextField)),
      '500',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cambio'), findsOneWidget);
    expect(find.text('330.00'), findsOneWidget);
    expect(botonPrincipal(tester).onPressed, isNotNull);
  });

  testWidgets('toda la ropa no sale debiendo, y se arregla desde el aviso', (
    tester,
  ) async {
    final orden = await crearOrden(abono: 20);

    await abrirDetalle(tester, orden.id);

    await tester.tap(find.text('Marcar lo pendiente'));
    await tester.pumpAndSettle();

    expect(find.byType(AvisoEntregaSinPagar), findsOneWidget);
    expect(botonPrincipal(tester).onPressed, isNull);

    await tester.tap(find.text('Cobrar lo que falta'));
    await tester.pumpAndSettle();

    expect(find.byType(AvisoEntregaSinPagar), findsNothing);
    expect(find.text('Cobrar 150.00 y entregar'), findsOneWidget);
    expect(botonPrincipal(tester).onPressed, isNotNull);
  });

  testWidgets('pagada, el cobro desaparece y sólo queda entregar', (
    tester,
  ) async {
    final orden = await crearOrden(abono: 170);

    await abrirDetalle(tester, orden.id);

    expect(find.byType(CobroDetalle), findsNothing);
    expect(find.byType(OrdenYaPagada), findsOneWidget);
    expect(casilla(tester, 'Sábana').onChanged, isNotNull);

    await tester.tap(find.text('Marcar lo pendiente'));
    await tester.pumpAndSettle();

    expect(find.text('Entregar 2 conceptos'), findsOneWidget);
    expect(botonPrincipal(tester).onPressed, isNotNull);
  });

  testWidgets('pagada y entregada, sólo el resumen', (tester) async {
    final orden = await crearOrden(abono: 170);
    await ordenes().registrarMovimiento(
      ordenId: orden.id,
      itemsAEntregar: orden.items.map((i) => i.id),
    );

    await abrirDetalle(tester, orden.id);

    expect(find.byType(CierreOrden), findsOneWidget);
    expect(find.text('Pagada y entregada'), findsOneWidget);
    expect(find.byType(PagosOrden), findsOneWidget);

    // Nada que cobrar, nada que marcar, y un solo botón: el de cerrar.
    expect(find.byType(CobroDetalle), findsNothing);
    expect(find.text('Marcar lo pendiente'), findsNothing);
    expect(casilla(tester, 'Sábana').onChanged, isNull);
    expect(casilla(tester, 'Cobija').onChanged, isNull);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Cerrar'), findsOneWidget);
  });

  testWidgets('el resumen llama adelanto al cobro del alta', (tester) async {
    final orden = await crearOrden(abono: 20);
    await ordenes().registrarMovimiento(
      ordenId: orden.id,
      monto: 150,
      itemsAEntregar: orden.items.map((i) => i.id),
    );

    await abrirDetalle(tester, orden.id);

    expect(find.text('Adelanto con Efectivo'), findsOneWidget);
  });

  testWidgets('el resumen dice con cuánto pagó en efectivo', (tester) async {
    final orden = await crearOrden();
    await ordenes().registrarMovimiento(
      ordenId: orden.id,
      monto: 170,
      recibido: 500,
      itemsAEntregar: orden.items.map((i) => i.id),
    );

    await abrirDetalle(tester, orden.id);

    expect(find.text('Recibió 500.00 · cambio 330.00'), findsOneWidget);
  });

  testWidgets('cobrar y entregar todo cierra la orden y lo dice', (
    tester,
  ) async {
    final orden = await crearOrden();

    await abrirDetalle(tester, orden.id);

    await tester.tap(find.text('Marcar lo pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobrar lo que falta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cobrar 170.00 y entregar'));
    await tester.pumpAndSettle();

    expect(find.byType(OrdenDetalleDialog), findsNothing);
    expect(resultado, contains('quedó pagada y entregada'));

    final cerrada = await ordenes().detalle(orden.id);
    expect(cerrada?.estatus, EstatusOrdenType.cerrada);
  });
}
