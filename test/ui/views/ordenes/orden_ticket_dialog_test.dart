import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/orden_ticket_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/view_model/orden_ticket_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Una imagen PNG de un pixel: lo que el rasterizador falso entrega como
/// página.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Sin PDFium: devuelve una página de un pixel.
class _VistaPreviaFalsa extends VistaPreviaPdf {
  const _VistaPreviaFalsa();

  @override
  Future<List<Uint8List>> paginas(Uint8List pdf) async => [_pixel];
}

/// Sin diálogo del sistema: anota qué le pidieron guardar.
class _GuardadoFalso extends GuardadoPdf {
  Uint8List? pdf;
  String? nombre;

  @override
  Future<String?> guardar(Uint8List pdf, {required String nombre}) async {
    this.pdf = pdf;
    this.nombre = nombre;
    return 'C:/Tickets/$nombre';
  }
}

/// Sin servidor: anota el correo, o falla si se le pide.
class _CorreoFalso extends EnvioCorreo {
  String? destinatario;
  String? nombreAdjunto;
  Uint8List? adjunto;
  CorreoEnvioData? cuenta;
  String? falla;

  @override
  Future<void> enviar({
    required CorreoEnvioData cuenta,
    required String remitente,
    required String destinatario,
    required String asunto,
    required String html,
    required Uint8List adjunto,
    required String nombreAdjunto,
  }) async {
    final falla = this.falla;
    if (falla != null) throw EnvioCorreoException(falla);

    this.cuenta = cuenta;
    this.destinatario = destinatario;
    this.adjunto = adjunto;
    this.nombreAdjunto = nombreAdjunto;
  }
}

/// El ticket se ve, se descarga y se envía, y los tres usan el mismo PDF.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;
  late _GuardadoFalso guardado;
  late _CorreoFalso correo;
  late OrdenDetalleData orden;

  const cuenta = CorreoEnvioData(
    servidor: 'smtp.gmail.com',
    puerto: 465,
    usuario: 'tickets@gmail.com',
    password: 'abcd efgh ijkl mnop',
  );

  /// Guarda la empresa, con o sin cuenta de correo.
  Future<void> configurarEmpresa({bool conCorreo = true}) {
    return instance<EmpresaLocalDatasource>().guardar(
      EmpresaData(
        nombre: 'Lavandería El Sol',
        telefono: '5551234567',
        password: 'admin',
        correoEnvio: conCorreo ? cuenta : const CorreoEnvioData(),
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

  /// El contenedor del diálogo abierto, para esperar su lectura.
  ProviderContainer contenedor(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(OrdenTicketDialog)));

  Future<void> abrirTicket(
    WidgetTester tester, {
    Size tamano = const Size(1400, 900),
  }) async {
    await tester.binding.setSurfaceSize(tamano);
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
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => OrdenTicketDialog(ordenId: orden.id),
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

    // Generar el PDF lee fuentes y escribe bytes: va fuera del reloj falso.
    await tester.runAsync(
      () =>
          contenedor(tester)
              .read(ordenTicketViewModelProvider(orden.id).notifier)
              .cargar(),
    );
    await tester.pumpAndSettle();
  }

  /// Deja aparecer el aviso de éxito. No con `pumpAndSettle`: el aviso trae
  /// una animación que se repite y nunca termina de asentarse.
  Future<void> esperarAviso(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  OrdenTicketState estado(WidgetTester tester) =>
      contenedor(tester).read(ordenTicketViewModelProvider(orden.id));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    guardado = _GuardadoFalso();
    correo = _CorreoFalso();
    instance
      ..registerLazySingleton<VistaPreviaPdf>(() => const _VistaPreviaFalsa())
      ..registerLazySingleton<GuardadoPdf>(() => guardado)
      ..registerLazySingleton<EnvioCorreo>(() => correo);

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
    await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion(
        categoriaId: Value(categoriaId),
        clotheSize: const Value(ClotheSizeType.emptySize),
        nombreConcepto: const Value('Sábana'),
        diasEntrega: const Value(2),
        tipoUnidad: const Value(UnitType.pieza),
        importe: const Value(50),
        estatus: const Value(EstatusType.activo),
      ),
    );
    final catalogo = await instance<PreciosLocalDatasource>().activos();

    orden = await instance<OrdenesLocalDatasource>().crearOrden(
      clienteId: clienteId,
      items: [
        ItemOrdenData(
          precio: catalogo.single,
          fechaEntrega: DateTime(2026, 11),
        ),
      ],
      abono: 20,
    );
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('enseña la vista previa y las dos acciones', (tester) async {
    await configurarEmpresa();

    await abrirTicket(tester);

    expect(find.text('Ticket · Orden ${orden.folio}'), findsOneWidget);
    expect(find.bySemanticsLabel('Vista previa del ticket'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Descargar PDF'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Enviar por correo'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('descargar guarda ese mismo PDF, con el folio en el nombre', (
    tester,
  ) async {
    await configurarEmpresa();
    await abrirTicket(tester);

    await tester.tap(find.text('Descargar PDF'));
    await esperarAviso(tester);

    expect(guardado.nombre, 'Ticket ${orden.folio}.pdf');
    expect(guardado.pdf, estado(tester).pdf);
    expect(
      find.text('El ticket se guardó en C:/Tickets/Ticket ${orden.folio}.pdf'),
      findsOneWidget,
    );
  });

  testWidgets('sin cuenta de correo, dice dónde configurarla', (tester) async {
    await configurarEmpresa(conCorreo: false);
    await abrirTicket(tester);

    await tester.tap(find.text('Enviar por correo'));
    await tester.pumpAndSettle();

    expect(find.text('Falta la cuenta de correo'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('envía el PDF al correo del cliente', (tester) async {
    await configurarEmpresa();
    await abrirTicket(tester);

    await tester.tap(find.text('Enviar por correo'));
    await tester.pumpAndSettle();

    // Propone el correo que dio el cliente.
    expect(find.text('lucia@correo.com'), findsOneWidget);

    await tester.tap(find.text('Enviar'));
    await esperarAviso(tester);

    expect(correo.destinatario, 'lucia@correo.com');
    expect(correo.cuenta, cuenta);
    expect(correo.nombreAdjunto, 'Ticket ${orden.folio}.pdf');
    expect(correo.adjunto, estado(tester).pdf);
    expect(find.byType(EnviarTicketDialog), findsNothing);
    expect(
      find.text(
        'Se envió el ticket de la orden ${orden.folio} a lucia@correo.com.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('si el servidor lo rechaza, lo dice ahí mismo', (tester) async {
    await configurarEmpresa();
    correo.falla = 'El servidor rechazó la contraseña.';
    await abrirTicket(tester);

    await tester.tap(find.text('Enviar por correo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    // El diálogo sigue abierto, con el motivo, para reintentar.
    expect(find.byType(EnviarTicketDialog), findsOneWidget);
    expect(find.text('El servidor rechazó la contraseña.'), findsOneWidget);
  });

  testWidgets('un correo mal escrito no se envía', (tester) async {
    await configurarEmpresa();
    await abrirTicket(tester);

    await tester.tap(find.text('Enviar por correo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lucia@');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('El correo no es válido'), findsOneWidget);
    expect(correo.destinatario, isNull);
  });

  testWidgets('cabe en ventanas chicas y grandes', (tester) async {
    await configurarEmpresa();

    for (final tamano in const [
      Size(1920, 1080),
      Size(1144, 643),
      Size(640, 800),
      Size(420, 760),
    ]) {
      await abrirTicket(tester, tamano: tamano);

      expect(tester.takeException(), isNull, reason: '$tamano');

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
    }
  });
}
