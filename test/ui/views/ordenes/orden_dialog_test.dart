import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/dialogs/cliente_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/orden_dialog.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/view_model/orden_dialog_view_model.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba el alta de una orden tal como se captura: tocar un concepto para
/// agregarlo, buscar al cliente, cobrar y crear.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// El folio que el diálogo devolvió al cerrarse, o `null` si se salió
  /// sin guardar.
  String? resultado;

  Future<void> sembrarCatalogo() async {
    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: const Value('Ropa de cama'),
        estatus: const Value(EstatusType.activo),
        diasEntrega: const Value(2),
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
  }

  Future<void> sembrarCliente({String nombres = 'Lucía'}) {
    return db.clientesDao.insertCliente(
      ClienteCompanion(
        nombres: Value(nombres),
        apellidos: const Value('Pérez'),
        telefono: const Value('5559998888'),
        correo: const Value('lucia@correo.com'),
      ),
    );
  }

  /// Abre el diálogo como lo abre el listado y espera a que lea el catálogo.
  Future<void> abrirDialogo(
    WidgetTester tester, {
    Size tamano = const Size(1400, 900),
  }) async {
    await tester.binding.setSurfaceSize(tamano);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // Con la densidad de escritorio, que es donde corre la aplicación.
          // No es un detalle de adorno: Material le resta ocho píxeles de alto
          // a sus controles en escritorio, y no todos la aplican igual —un
          // `TextField` sí, un `DropdownMenu` no—, así que una fila que sale
          // cuadrada con los valores de omisión puede salir descuadrada en la
          // ventana de verdad. Se declara aquí en lugar de cambiar la
          // plataforma de las pruebas porque el framework no deja tocar esa
          // variable global sin reponerla dentro de cada prueba.
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
                    builder: (context) => const OrdenDialog(),
                  );
                },
                child: const Text('Nueva orden'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Nueva orden'));
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(OrdenDialog)),
    );

    await contenedor.read(ordenDialogViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  /// Escribe en el buscador que lleva [etiqueta] y espera a que avise.
  Future<void> buscar(
    WidgetTester tester,
    String etiqueta,
    String texto,
  ) async {
    await tester.enterText(
      find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField)),
      texto,
    );

    // El buscador espera a que se deje de escribir antes de avisar.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    resultado = null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('el catálogo muestra el concepto con lo que hace falta', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    // Nombre, categoría, días de entrega, unidad y precio, todo en el mismo
    // renglón: es lo que hace falta para elegir sin abrir nada.
    final sabana = find.ancestor(
      of: find.text('Sábana'),
      matching: find.byType(ListTile),
    );

    expect(sabana, findsOneWidget);
    expect(
      find.descendant(
        of: sabana,
        matching: find.text('Ropa de cama · 2 días · Pieza'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sabana, matching: find.text('50.00')),
      findsOneWidget,
    );
  });

  testWidgets('sin cliente ni ropa no se puede crear', (tester) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    final crear = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear orden · 0.00'),
    );

    expect(crear.onPressed, isNull);
  });

  testWidgets('cuando el cliente no existe ofrece registrarlo', (tester) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(tester, 'Buscar por nombre, teléfono o correo', 'Lucía');

    expect(find.text('Nadie coincide con "Lucía".'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Registrar'), findsOneWidget);
  });

  testWidgets('registrar al cliente llega con lo tecleado ya repartido', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(
      tester,
      'Buscar por nombre, teléfono o correo',
      'Ulises Shie Sotelo Chopin',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    // El alta nace con el nombre repartido: lo que se escribió para buscar no
    // se vuelve a escribir.
    expect(find.byType(ClienteDialog), findsOneWidget);
    expect(find.text('Ulises Shie'), findsOneWidget);
    expect(find.text('Sotelo Chopin'), findsOneWidget);
  });

  testWidgets('buscar por teléfono registra con el teléfono puesto', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);
    await buscar(tester, 'Buscar por nombre, teléfono o correo', '5559998888');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    // Un teléfono no es un nombre: va al campo que le toca.
    expect(find.text('5559998888'), findsWidgets);
    expect(
      tester
          .widget<TextField>(
            find.ancestor(
              of: find.text('Nombre(s)'),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('el adelanto nace vacío, con el importe como pista', (
    tester,
  ) async {
    await sembrarCatalogo();
    await sembrarCliente();

    await abrirDialogo(tester);

    TextField campo() => tester.widget<TextField>(
      find.ancestor(
        of: find.text('Adelanto'),
        matching: find.byType(TextField),
      ),
    );

    // Una orden nace sin nada pagado: el campo está vacío y lo que se ve es
    // la pista, no un importe capturado que haya que borrar antes de teclear.
    expect(campo().controller?.text, isEmpty);
    expect(campo().decoration?.hintText, '0.00');

    // El atajo de pagar todo sí escribe el importe.
    await tester.tap(find.text('Sábana'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todo'));
    await tester.pumpAndSettle();

    expect(campo().controller?.text, '50.00');

    // Y el de no dejar nada lo vacía de nuevo.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Nada'));
    await tester.pumpAndSettle();

    expect(campo().controller?.text, isEmpty);
  });

  testWidgets('con adelanto en efectivo pide con cuánto paga y da el cambio', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    // Sin adelanto no hay billete: la fila no ocupa sitio.
    expect(find.text('Recibe'), findsNothing);

    await tester.tap(find.text('Cobija'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(of: find.text('Adelanto'), matching: find.byType(TextField)),
      '100',
    );
    await tester.pumpAndSettle();

    expect(find.text('Recibe'), findsOneWidget);
    expect(find.text('Sin cambio'), findsOneWidget);

    await tester.enterText(
      find.ancestor(of: find.text('Recibe'), matching: find.byType(TextField)),
      '500',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cambio'), findsOneWidget);
    expect(find.text('400.00'), findsOneWidget);

    // Con tarjeta no hay cambio que sacar.
    await tester.tap(find.byType(DropdownMenu<MetodoPagoType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta').last);
    await tester.pumpAndSettle();

    expect(find.text('Recibe'), findsNothing);
  });

  testWidgets('la fila del efectivo cuadra con la de arriba', (tester) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    await tester.tap(find.text('Cobija'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todo'));
    await tester.pumpAndSettle();

    Rect campo(String etiqueta) => tester.getRect(
      find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField)),
    );

    final metodo = tester.getRect(find.byType(DropdownMenu<MetodoPagoType>));
    final adelanto = campo('Adelanto');
    final recibe = campo('Recibe');
    final cambio = tester.getRect(
      find.ancestor(of: find.text('Sin cambio'), matching: find.byType(Container)).first,
    );

    // Mismo alto que los controles de arriba.
    expect(recibe.height, metodo.height);
    expect(cambio.height, metodo.height);

    // Y a plomo: «Recibe» bajo el método de pago, el cambio bajo el adelanto.
    expect(recibe.left, metodo.left);
    expect(recibe.right, metodo.right);
    expect(cambio.left, adelanto.left);
    expect(cambio.top, recibe.top);
  });

  testWidgets('los cuatro controles del cobro miden y empiezan igual', (
    tester,
  ) async {
    await sembrarCatalogo();

    await abrirDialogo(tester);

    // El marco que se ve de un campo lo pinta su `InputDecorator`; el de un
    // botón, su propia caja. Son los cuatro trozos que el ojo compara.
    final cajas = <String, Rect>{
      'método de pago': tester.getRect(
        find.descendant(
          of: find.byType(CobroOrden),
          matching: find.byType(DropdownMenu<MetodoPagoType>),
        ),
      ),
      // Por su etiqueta: el desplegable también lleva un campo de texto
      // dentro, y por tipo salen los dos.
      'adelanto': tester.getRect(
        find.ancestor(
          of: find.text('Adelanto'),
          matching: find.byType(TextField),
        ),
      ),
      'nada': tester.getRect(find.widgetWithText(FilledButton, 'Nada')),
      'todo': tester.getRect(find.widgetWithText(OutlinedButton, 'Todo')),
    };

    final referencia = cajas['método de pago']!;

    for (final MapEntry(key: nombre, value: caja) in cajas.entries) {
      expect(
        caja.height,
        referencia.height,
        reason: 'el control "$nombre" no mide lo mismo que el desplegable',
      );
      expect(
        caja.top,
        referencia.top,
        reason: 'el control "$nombre" no empieza donde el desplegable',
      );
    }
  });

  testWidgets('la orden entera se ve sin desplazar en una pantalla de '
      'portátil', (tester) async {
    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      const CategoriaServicioCompanion(
        nombre: Value('Lavandería'),
        estatus: Value(EstatusType.activo),
        diasEntrega: Value(1),
      ),
    );

    const prendas = ['Carga', 'Playera', 'Pantalón', 'Camisa', 'Saco', 'Falda'];

    for (final prenda in prendas) {
      await db.preciosConceptosDao.insertPrecio(
        PreciosConceptosCompanion(
          categoriaId: Value(categoriaId),
          clotheSize: const Value(ClotheSizeType.emptySize),
          nombreConcepto: Value(prenda),
          diasEntrega: const Value(1),
          tipoUnidad: const Value(UnitType.pieza),
          importe: const Value(100),
          estatus: const Value(EstatusType.activo),
        ),
      );
    }

    // La ventana de un portátil, que es donde aprieta: con el cobro en la
    // columna derecha no cabía ni la segunda prenda.
    await abrirDialogo(tester, tamano: const Size(1144, 643));

    // Se agregan por el modelo y no tocando el catálogo porque en esta
    // ventana el catálogo tampoco cabe entero: lo que se mide aquí es la
    // lista de la orden, no el desplazamiento del de al lado.
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(OrdenDialog)),
    );
    final notificador = contenedor.read(ordenDialogViewModelProvider.notifier);

    for (final concepto
        in contenedor.read(ordenDialogViewModelProvider).conceptos) {
      notificador.agregar(concepto);
    }
    await tester.pumpAndSettle();

    final lista = tester.getRect(find.byType(RenglonesOrden));

    // Los importes de la orden: uno por renglón puesto, y los que caen dentro
    // del hueco de la lista son los que se ven sin rodar la rueda.
    final dentro = find
        .descendant(
          of: find.byType(RenglonesOrden),
          matching: find.text('100.00'),
        )
        .evaluate()
        .map((elemento) => tester.getRect(find.byWidget(elemento.widget)))
        .where((renglon) => renglon.bottom <= lista.bottom + 1)
        .length;

    // Con la tipografía de prueba —donde cada letra ocupa un cuadro entero y
    // la banda de abajo se parte en dos renglones— se ven cinco de las seis;
    // con Poppins, que es la de la aplicación, caben las seis. Se exige
    // cuatro para que la prueba mida el reparto y no el ancho de la fuente.
    expect(dentro, greaterThanOrEqualTo(4));
  });

  testWidgets('se arma la orden tocando el concepto y se crea', (tester) async {
    await sembrarCatalogo();
    await sembrarCliente();

    await abrirDialogo(tester);

    // Dos toques sobre el mismo concepto son dos sábanas.
    await tester.tap(find.text('Sábana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sábana').first);
    await tester.pumpAndSettle();

    // El cliente se busca por teléfono y se elige de la lista.
    await buscar(tester, 'Buscar por nombre, teléfono o correo', '5559998888');
    await tester.tap(find.text('Lucía Pérez'));
    await tester.pumpAndSettle();

    // Paga todo con el atajo.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todo'));
    await tester.pumpAndSettle();

    expect(find.text('Pagada'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Crear orden · 100.00'));
    await tester.pumpAndSettle();

    // El diálogo se cierra con el folio de lo que guardó, y la orden está
    // en la base.
    expect(resultado, matches(r'^\d{4}-\d{4}$'));
    expect(find.byType(OrdenDialog), findsNothing);

    final ordenes = await instance<OrdenesLocalDatasource>().listado();
    final orden = ordenes.single;

    expect(orden.cliente, 'Lucía Pérez');
    expect(orden.total, 100);
    expect(orden.restante, 0);
    expect(orden.estatus, EstatusOrdenType.pagado);
  });
}
