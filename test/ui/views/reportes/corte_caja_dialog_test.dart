import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:gestion_lavanderia/ui/views/reportes/reportes_view.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/corte_caja_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/guardado_falso.dart';
import '../../../support/inyeccion_de_prueba.dart';

/// El corte de caja desde la sección de reportes: de hoy de entrada, otro
/// día con un toque en el calendario, y se guarda en PDF.
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
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1144, 900));
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
    await tester.pumpAndSettle();
  }

  /// Genera y espera a que la base, el archivo y el aviso terminen.
  Future<void> generar(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Generar PDF'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('de entrada es el corte de hoy, y se guarda en PDF', (
    tester,
  ) async {
    await abrirDialogo(tester);

    expect(find.textContaining('Hoy, '), findsOneWidget);

    await generar(tester);

    expect(guardado.nombre, CorteCajaViewModel.nombreArchivo(DateTime.now()));
    expect(guardado.extension, 'pdf');
    expect(ascii.decode(guardado.bytes!.take(5).toList()), '%PDF-');
    expect(
      find.text('El corte de caja se guardó en C:/Reportes/${guardado.nombre}'),
      findsOneWidget,
    );
  });

  testWidgets('se puede pedir el de otro día', (tester) async {
    await abrirDialogo(tester);

    // El día 1 del mes en curso: siempre está en el calendario y nunca es
    // futuro. Si hoy es día 1, es hoy.
    final hoy = DateTime.now();
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();

    await generar(tester);

    expect(
      guardado.nombre,
      CorteCajaViewModel.nombreArchivo(DateTime(hoy.year, hoy.month)),
    );
  });

  test('el nombre del archivo lleva el día', () {
    expect(
      CorteCajaViewModel.nombreArchivo(DateTime(2026, 11, 4, 18)),
      'Corte de caja 2026-11-04.pdf',
    );
  });
}
