import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/avisos/aviso_ropa_lista.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/orden_detalle_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/view_model/orden_detalle_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Sin servidor: anota el correo que se le pidió enviar.
class _CorreoFalso extends EnvioCorreo {
  String? destinatario;
  String? html;

  @override
  Future<void> enviar({
    required CorreoEnvioData cuenta,
    required String remitente,
    required String destinatario,
    required String asunto,
    required String html,
    Uint8List? adjunto,
    String nombreAdjunto = '',
  }) async {
    this.destinatario = destinatario;
    this.html = html;
  }
}

/// La ropa se marca como lista desde el detalle. Si el aviso está encendido
/// y hay a quién y desde dónde enviarlo, se pide confirmación antes de
/// guardar, porque el correo no se puede deshacer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late OrdenDetalleData orden;
  late _CorreoFalso correo;

  MovimientoRegistrado? resultado;

  OrdenesLocalDatasource ordenes() => instance<OrdenesLocalDatasource>();

  /// Enciende el aviso, con el correo falso.
  void encenderAviso() {
    instance.registerLazySingleton<AvisoRopaLista>(
      () => AvisoRopaLista(correo, habilitado: true),
    );
  }

  Future<void> configurarEmpresa({bool conCorreo = true}) {
    return instance<EmpresaLocalDatasource>().guardar(
      EmpresaData(
        nombre: 'Lavandería El Sol',
        telefono: '5551234567',
        password: 'admin',
        correoEnvio: conCorreo
            ? const CorreoEnvioData(
                servidor: 'smtp.gmail.com',
                puerto: 587,
                usuario: 'sol@gmail.com',
                password: 'clave',
              )
            : const CorreoEnvioData(),
        direccion: const DireccionData(
          calle: 'Reforma',
          numeroExterior: '12',
          colonia: 'Centro',
          codigoPostal: 6000,
          ciudad: 'CDMX',
          estado: 'CDMX',
        ),
      ),
    );
  }

  Future<void> abrirDetalle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<MovimientoRegistrado>(
                    context: context,
                    builder: (context) => OrdenDetalleDialog(ordenId: orden.id),
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
    await tester.runAsync(
      () => ProviderScope.containerOf(
        tester.element(find.byType(OrdenDetalleDialog)),
      ).read(ordenDetalleViewModelProvider(orden.id).notifier).cargar(),
    );
    await tester.pumpAndSettle();
  }

  /// La etiqueta "Lista" del renglón de [concepto].
  Finder etiquetaLista(String concepto) => find.descendant(
    of: find
        .ancestor(of: find.text(concepto), matching: find.byType(Row))
        .first,
    matching: find.widgetWithText(FilterChip, 'Lista'),
  );

  /// Guarda, y espera a la base y al correo, que corren fuera del reloj
  /// falso de la prueba.
  Future<void> guardar(WidgetTester tester, String boton) async {
    await tester.tap(find.widgetWithText(FilledButton, boton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    // El aviso de advertencia trae una animación que nunca se asienta.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<bool> estaLista(String concepto) async {
    final actual = await ordenes().detalle(orden.id);
    return actual!.items
        .firstWhere((item) => item.precio.nombreConcepto == concepto)
        .estaListo;
  }

  setUp(() async {
    resultado = null;
    correo = _CorreoFalso();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    final clienteId = await db.clientesDao.insertCliente(
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

    final catalogo = await instance<PreciosLocalDatasource>().activos();
    orden = await ordenes().crearOrden(
      clienteId: clienteId,
      items: [
        for (final precio in catalogo)
          ItemOrdenData(precio: precio, fechaEntrega: DateTime(2026, 10, 25)),
      ],
    );
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('con el aviso apagado, marca la ropa como lista sin preguntar', (
    tester,
  ) async {
    await configurarEmpresa();
    await abrirDetalle(tester);

    await tester.tap(etiquetaLista('Sábana'));
    await tester.pumpAndSettle();
    await guardar(tester, 'Marcar 1 concepto como listo');

    expect(find.text('Avisar al cliente'), findsNothing);
    expect(await tester.runAsync(() => estaLista('Sábana')), isTrue);
    expect(await tester.runAsync(() => estaLista('Cobija')), isFalse);
    expect(correo.html, isNull);
    expect(
      resultado?.mensaje,
      'Se marcó 1 concepto como listo en la orden ${orden.folio}.',
    );
  });

  testWidgets('con el aviso encendido pide confirmación y envía la lista', (
    tester,
  ) async {
    encenderAviso();
    await configurarEmpresa();
    await abrirDetalle(tester);

    await tester.tap(find.text('Todo listo'));
    await tester.pumpAndSettle();
    await guardar(tester, 'Marcar 2 conceptos como listos');

    expect(find.text('Avisar al cliente'), findsOneWidget);
    // El correo del cliente, en el aviso (también está en su ficha).
    expect(
      find.descendant(
        of: find.byType(Dialog).last,
        matching: find.textContaining('lucia@correo.com'),
      ),
      findsOneWidget,
    );

    // Si se cancela, no se guarda nada ni sale ningún correo.
    await tester.tap(find.text('Cancelar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await tester.runAsync(() => estaLista('Sábana')), isFalse);
    expect(correo.html, isNull);
    expect(find.byType(OrdenDetalleDialog), findsOneWidget);

    await guardar(tester, 'Marcar 2 conceptos como listos');
    await tester.tap(find.text('Marcar y avisar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(await tester.runAsync(() => estaLista('Sábana')), isTrue);
    expect(correo.destinatario, 'lucia@correo.com');
    expect(correo.html, contains('Sábana'));
    expect(correo.html, contains('Cobija'));
    expect(resultado?.mensaje, contains('Se le avisó por correo a lucia@'));
  });

  testWidgets('sin cuenta de correo, no pregunta ni envía aunque esté '
      'encendido', (tester) async {
    encenderAviso();
    await configurarEmpresa(conCorreo: false);
    await abrirDetalle(tester);

    await tester.tap(etiquetaLista('Cobija'));
    await tester.pumpAndSettle();
    await guardar(tester, 'Marcar 1 concepto como listo');

    expect(find.text('Avisar al cliente'), findsNothing);
    expect(await tester.runAsync(() => estaLista('Cobija')), isTrue);
    expect(correo.html, isNull);
  });

  testWidgets('lo ya listo lo dice y no ofrece la etiqueta', (tester) async {
    await ordenes().marcarListos(
      ordenId: orden.id,
      itemIds: [orden.items.first.id],
    );
    await abrirDetalle(tester);

    expect(find.textContaining('Lista desde el'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Lista'), findsOneWidget);
  });
}
