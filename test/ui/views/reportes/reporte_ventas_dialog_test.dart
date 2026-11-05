import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/ui/views/reportes/reportes_view.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/reporte_ventas_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/guardado_falso.dart';
import '../../../support/inyeccion_de_prueba.dart';

/// La sección de reportes y el diálogo del reporte de ventas: se elige el
/// periodo, se dice en qué sale y se guarda.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late GuardadoFalso guardado;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    guardado = GuardadoFalso();
    instance.registerLazySingleton<GuardadoArchivo>(() => guardado);

    final clienteId = await db.clientesDao.insertCliente(
      const ClienteCompanion(
        nombres: Value('Lucía'),
        apellidos: Value('Pérez'),
        telefono: Value('5559998888'),
        correo: Value('lucia@correo.com'),
      ),
    );
    // Una orden de hoy: la fecha la pone la inserción.
    await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.enCurso,
        total: 100,
        restante: 100,
        fechaCreacion: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1144, 800));
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
    await tester.tap(botonDeLaTarjeta('Reporte general de ventas'));
    await tester.pumpAndSettle();
  }

  Future<void> elegir(WidgetTester tester, String periodo) async {
    await tester.tap(find.widgetWithText(ChoiceChip, periodo));
    await tester.pumpAndSettle();
  }

  /// Genera y espera a que la base, el archivo y el aviso terminen.
  Future<void> generar(WidgetTester tester, String boton) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, boton));
      // Lo que tarda de verdad —la base y el archivo— corre fuera del
      // reloj falso de la prueba.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    // El aviso de éxito lleva una animación que no se asienta.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('hoy sale en PDF, y se guarda con la fecha en el nombre', (
    tester,
  ) async {
    await abrirDialogo(tester);

    await generar(tester, 'Generar PDF');

    final hoy = DateTime.now();
    final dia =
        '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';
    expect(guardado.nombre, 'Reporte de ventas $dia.pdf');
    expect(guardado.extension, 'pdf');
    expect(ascii.decode(guardado.bytes!.take(5).toList()), '%PDF-');
    expect(
      find.text('El reporte se guardó en C:/Reportes/${guardado.nombre}'),
      findsOneWidget,
    );
    // Sin la casilla, sólo el PDF.
    expect(guardado.bytesJunto, isNull);
  });

  testWidgets('aunque sean tres meses, sale en PDF', (tester) async {
    await abrirDialogo(tester);
    await elegir(tester, 'Tres meses');

    await generar(tester, 'Generar PDF');

    expect(guardado.extension, 'pdf');
    expect(ascii.decode(guardado.bytes!.take(5).toList()), '%PDF-');
  });

  testWidgets('con la casilla, el Excel se guarda junto al PDF', (
    tester,
  ) async {
    await abrirDialogo(tester);
    await tester.tap(find.text('También en Excel'));
    await tester.pumpAndSettle();

    await generar(tester, 'Generar PDF y Excel');

    expect(guardado.extension, 'pdf');
    // Un .xlsx es un zip: empieza con `PK`.
    expect(ascii.decode(guardado.bytesJunto!.take(2).toList()), 'PK');
    expect(guardado.rutaJunto, endsWith('.xlsx'));
    expect(
      find.text(
        'El reporte se guardó en C:/Reportes/${guardado.nombre}, y el '
        'Excel junto a él.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('otras fechas pide las fechas antes de generar', (tester) async {
    await abrirDialogo(tester);
    await elegir(tester, 'Otras fechas');

    expect(find.text('Elige las fechas del reporte.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Generar PDF'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('si se cierra el diálogo de guardar, el reporte sigue abierto', (
    tester,
  ) async {
    guardado.cancelar = true;
    await abrirDialogo(tester);

    await generar(tester, 'Generar PDF');

    expect(find.text('Reporte general de ventas'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Generar PDF'), findsOneWidget);
  });

  group('el periodo elegido a mano', () {
    final ahora = DateTime(2026, 11, 4, 18);

    test('con un solo día, es ese día', () {
      final estado = ReporteVentasState(
        periodo: PeriodoReporte.rango,
        fechas: [DateTime(2026, 10, 2)],
      );

      expect(
        estado.rangoAl(ahora),
        RangoReporte(DateTime(2026, 10, 2), DateTime(2026, 10, 2)),
      );
    });

    test('con dos, va de una a la otra', () {
      final estado = ReporteVentasState(
        periodo: PeriodoReporte.rango,
        fechas: [DateTime(2026, 10, 20), DateTime(2026, 9, 1)],
      );

      final rango = estado.rangoAl(ahora)!;
      expect(rango.desde, DateTime(2026, 9));
      expect(rango.hasta, DateTime(2026, 10, 20));
    });

    test('el nombre del archivo lleva las dos fechas', () {
      expect(
        ReporteVentasViewModel.nombreArchivo(
          RangoReporte(DateTime(2026, 10, 5), DateTime(2026, 11, 4)),
        ),
        'Reporte de ventas 2026-10-05 al 2026-11-04.pdf',
      );
    });
  });
}
