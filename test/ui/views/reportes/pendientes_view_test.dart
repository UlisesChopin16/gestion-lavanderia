import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/types/clothe_size_type.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';
import 'package:gestion_lavanderia/ui/views/reportes/reportes_view.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/guardado_falso.dart';
import '../../../support/inyeccion_de_prueba.dart';

/// Las cuentas por cobrar y la ropa pendiente, abiertas desde la sección de
/// reportes: lo que se ve y los filtros de la lista.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late int precioId;
  final hoy = DateTime.now().soloDia;
  DateTime dia(int dias) => DateTime(hoy.year, hoy.month, hoy.day + dias, 10);

  var clientes = 0;

  /// Una orden de un cliente nuevo, recibida hace [hace] días, con [saldo] y
  /// un renglón de ropa prometido para dentro de [entrega] días; lista desde
  /// hace [listaHace] días, si se da.
  Future<void> orden({
    required String nombre,
    required int hace,
    required double saldo,
    int? entrega,
    int? listaHace,
  }) async {
    clientes++;
    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: nombre,
        apellidos: 'Pérez',
        correo: 'cliente$clientes@example.com',
        telefono: '55500000$clientes',
        fechaCreacion: DateTime.now(),
      ),
    );
    final creada = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: saldo > 0 ? EstatusOrdenType.enCurso : EstatusOrdenType.pagado,
        total: 200,
        restante: saldo,
        fechaCreacion: dia(-hace),
      ),
    );
    await (db.update(db.ordenServicio)..where((t) => t.id.equals(creada.id)))
        .write(OrdenServicioCompanion(fechaCreacion: Value(dia(-hace))));

    if (entrega != null) {
      await db.itemServicioOrdenDao.insertItem(
        ItemServicioOrdenCompanion.insert(
          ordenId: creada.id,
          precioConceptoId: precioId,
          cantidad: 2,
          importe: 50,
          fechaEntrega: dia(entrega),
          fechaLista: Value(listaHace == null ? null : dia(-listaHace)),
          fechaCreacion: DateTime.now(),
        ),
      );
    }
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: 'Planchado',
        estatus: EstatusType.activo,
        diasEntrega: 2,
        fechaCreacion: DateTime.now(),
      ),
    );
    precioId = await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion.insert(
        categoriaId: categoriaId,
        clotheSize: ClotheSizeType.king,
        nombreConcepto: 'Camisa',
        diasEntrega: 2,
        tipoUnidad: UnitType.pieza,
        importe: 25,
        estatus: EstatusType.activo,
        fechaCreacion: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  Future<void> abrir(WidgetTester tester, String tarjeta) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: const ReportesView(),
        ),
      ),
    );
    await tester.tap(botonDeLaTarjeta(tarjeta));
    await cargar(tester);
  }

  group('cuentas por cobrar', () {
    testWidgets('lo que se debe, con el teléfono, y el filtro por antigüedad', (
      tester,
    ) async {
      await orden(nombre: 'Ana', hace: 45, saldo: 150);
      await orden(nombre: 'Luis', hace: 2, saldo: 50);
      await orden(nombre: 'Rosa', hace: 3, saldo: 0);

      await abrir(tester, 'Cuentas por cobrar');

      expect(find.text(r'$200.00'), findsWidgets);
      // Rosa ya pagó: no está.
      expect(find.textContaining('Rosa'), findsNothing);
      expect(find.text('555000001'), findsOneWidget);
      expect(find.text('555000002'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Más de un mes (1)'));
      await tester.pumpAndSettle();

      expect(find.text('555000001'), findsOneWidget);
      expect(find.text('555000002'), findsNothing);
    });

    testWidgets('sin saldos lo dice', (tester) async {
      await abrir(tester, 'Cuentas por cobrar');

      expect(
        find.text('Nadie debe nada. Todas las órdenes están pagadas.'),
        findsWidgets,
      );
    });
  });

  group('ropa pendiente', () {
    testWidgets('de entrada lo atrasado; los filtros cambian la lista', (
      tester,
    ) async {
      // Ana: ya pasó la fecha, pero está lista desde ayer. No es atraso.
      await orden(nombre: 'Ana', hace: 5, saldo: 0, entrega: -2, listaHace: 1);
      await orden(nombre: 'Luis', hace: 4, saldo: 80, entrega: -1);
      await orden(nombre: 'Rosa', hace: 1, saldo: 80, entrega: 0);
      await orden(nombre: 'Juan', hace: 1, saldo: 80, entrega: 3);

      await abrir(tester, 'Ropa pendiente');

      expect(find.text('Luis Pérez'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsNothing);
      expect(find.text('Rosa Pérez'), findsNothing);
      expect(find.text('2 Piezas Camisa'), findsWidgets);
      expect(find.text('Atrasada 1 día'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Lista para recoger (1)'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Pérez'), findsNothing);
      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('Lista hace 1 día'), findsOneWidget);
      expect(find.text('2 Piezas Camisa (lista)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Para hoy (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Rosa Pérez'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Todo lo pendiente (4)'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Juan Pérez'), findsOneWidget);
    });
  });
}

/// Espera a que la base conteste: la consulta corre fuera del reloj falso de
/// la prueba.
Future<void> cargar(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}
