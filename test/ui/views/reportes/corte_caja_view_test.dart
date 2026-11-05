import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/views/reportes/reportes_view.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/guardado_falso.dart';
import '../../../support/inyeccion_de_prueba.dart';

/// El corte de caja en pantalla: se abre desde la sección de reportes con
/// el de hoy, se cambia de día con las flechas y se regresa a las tarjetas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late int clienteId;
  final hoy = DateTime.now().soloDia;
  final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);

  /// Una orden pagada con un solo cobro en [fecha].
  Future<void> cobro(
    DateTime fecha,
    double monto,
    MetodoPagoType metodo, {
    double? recibido,
  }) async {
    final orden = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.pagado,
        total: monto,
        restante: 0,
        fechaCreacion: fecha,
      ),
    );
    await db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: orden.id,
        monto: monto,
        restante: 0,
        metodoPago: metodo,
        recibido: Value(recibido),
        fecha: fecha,
      ),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  Future<void> abrirCorte(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
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
    await tester.tap(botonDeLaTarjeta('Corte de caja'));
    await cargar(tester);
  }

  testWidgets('abre el corte de hoy con sus cifras y sus gráficas', (
    tester,
  ) async {
    await cobro(
      hoy.add(const Duration(hours: 10)),
      150,
      MetodoPagoType.efectivo,
      recibido: 500,
    );
    await cobro(
      hoy.add(const Duration(hours: 12)),
      200,
      MetodoPagoType.tarjeta,
    );

    await abrirCorte(tester);

    expect(find.textContaining('Hoy, '), findsOneWidget);
    // Total cobrado, debe haber en caja y cambio dado.
    expect(find.text(r'$350.00'), findsWidgets);
    expect(find.text(r'$150.00'), findsWidgets);
    expect(find.text('De \$500.00 que dieron los clientes'), findsOneWidget);
    // Por hora y los últimos siete días.
    expect(find.byType(BarChart), findsNWidgets(2));
    // Cada cobro en el detalle.
    expect(find.text('Tarjeta'), findsWidgets);
  });

  testWidgets('con la flecha se ve el día anterior', (tester) async {
    await cobro(
      ayer.add(const Duration(hours: 11)),
      80,
      MetodoPagoType.transferencia,
    );

    await abrirCorte(tester);
    expect(find.text('No se cobró nada este día.'), findsWidgets);

    await tester.tap(find.byTooltip('Día anterior'));
    await cargar(tester);

    expect(find.textContaining('Hoy, '), findsNothing);
    expect(find.text(r'$80.00'), findsWidgets);
    expect(find.text('Transferencia'), findsWidgets);

    // No se puede ir más allá de hoy, pero sí regresar a él.
    await tester.tap(find.byTooltip('Día siguiente'));
    await cargar(tester);
    expect(find.textContaining('Hoy, '), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('la flecha de volver regresa a las tarjetas', (tester) async {
    await abrirCorte(tester);

    await tester.tap(find.byTooltip('Volver a reportes'));
    await tester.pumpAndSettle();

    expect(find.text('Reportes y estadísticas'), findsOneWidget);
    expect(find.text('Corte de caja'), findsOneWidget);
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
