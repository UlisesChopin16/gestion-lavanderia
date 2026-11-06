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

/// Las entregas a tiempo, abiertas desde la sección de reportes: el
/// porcentaje del periodo, el cambio de periodo y lo entregado tarde por
/// categoría.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late int ordenId;
  final precios = <String, int>{};
  final hoy = DateTime.now().soloDia;
  DateTime dia(int dias) => DateTime(hoy.year, hoy.month, hoy.day + dias, 12);

  /// Un concepto de [categoria] prometido hace [prometida] días, listo hace
  /// [lista] y, si se da, entregado hace [entregada].
  Future<void> entrega(
    String categoria, {
    required int prometida,
    required int lista,
    int? entregada,
  }) {
    return db.itemServicioOrdenDao.insertItem(
      ItemServicioOrdenCompanion.insert(
        ordenId: ordenId,
        precioConceptoId: precios[categoria]!,
        cantidad: 1,
        importe: 25,
        estaEntregado: Value(entregada != null),
        fechaEntrega: dia(-prometida),
        fechaLista: Value(dia(-lista)),
        fechaEntregado: Value(entregada == null ? null : dia(-entregada)),
        fechaCreacion: DateTime.now(),
      ),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    for (final (categoria, concepto) in [
      ('Planchado', 'Camisa'),
      ('Edredones', 'Edredón'),
    ]) {
      final categoriaId = await db.categoriaServicioDao.insertCategoria(
        CategoriaServicioCompanion.insert(
          nombre: categoria,
          estatus: EstatusType.activo,
          diasEntrega: 2,
          fechaCreacion: DateTime.now(),
        ),
      );
      precios[categoria] = await db.preciosConceptosDao.insertPrecio(
        PreciosConceptosCompanion.insert(
          categoriaId: categoriaId,
          clotheSize: ClotheSizeType.king,
          nombreConcepto: concepto,
          diasEntrega: 2,
          tipoUnidad: UnitType.pieza,
          importe: 25,
          estatus: EstatusType.activo,
          fechaCreacion: DateTime.now(),
        ),
      );
    }

    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );
    ordenId = (await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.cerrada,
        total: 100,
        restante: 0,
        fechaCreacion: dia(-60),
      ),
    )).id;
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  Future<void> abrir(WidgetTester tester) async {
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
    await tester.tap(botonDeLaTarjeta('Entregas a tiempo'));
    await cargar(tester);
  }

  testWidgets('el porcentaje del mes y lo entregado tarde por categoría', (
    tester,
  ) async {
    // Lista a tiempo, aunque el cliente pasó tres días después.
    await entrega('Planchado', prometida: 10, lista: 10, entregada: 7);
    await entrega('Planchado', prometida: 9, lista: 10, entregada: 10);
    await entrega('Planchado', prometida: 8, lista: 5, entregada: 5);
    await entrega('Edredones', prometida: 6, lista: 2);
    // Hace dos meses: fuera del mes, dentro de los tres meses.
    await entrega('Edredones', prometida: 62, lista: 60, entregada: 60);

    await abrir(tester);

    // Del mes: 2 de 4 a tiempo.
    expect(find.text('50 %'), findsWidgets);
    expect(find.text('2 de 4 conceptos terminados'), findsOneWidget);
    // Recogieron a los 3, 0 y 0 días de estar listos; uno sigue esperando.
    expect(find.text('1.0 días'), findsOneWidget);
    expect(find.text('1 todavía sin recoger'), findsOneWidget);
    // Lo tarde: la camisa con 3 días y el edredón con 4.
    expect(find.text('3 días'), findsOneWidget);
    expect(find.text('4 días'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Edredones (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1 Pieza Camisa'), findsNothing);
    expect(find.text('1 Pieza Edredón'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tres meses'));
    await cargar(tester);
    expect(find.text('2 de 5 conceptos terminados'), findsOneWidget);
  });

  testWidgets('sin entregas lo dice', (tester) async {
    await abrir(tester);

    expect(find.text('No se terminó ropa en este periodo.'), findsOneWidget);
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
