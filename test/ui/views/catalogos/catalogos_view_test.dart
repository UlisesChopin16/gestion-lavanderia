import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/catalogos_view.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/view_model/categorias_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/view_model/clientes_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba la forma del módulo: la tarjeta llena el espacio, el encabezado
/// lleva el nombre del catálogo y el botón de agregar, el buscador va con los
/// demás filtros, la paginación entre ellos y la tabla, y las pestañas llevan
/// de un catálogo a otro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  /// [cuantos] clientes, que es lo que se necesita para que haya más de una
  /// página.
  Future<void> sembrarClientes(int cuantos) async {
    for (var numero = 1; numero <= cuantos; numero++) {
      await db.clientesDao.insertCliente(
        ClienteCompanion(
          nombres: Value('Cliente $numero'),
          apellidos: const Value('Pérez'),
          telefono: Value('55${numero.toString().padLeft(8, '0')}'),
          correo: Value('cliente$numero@correo.com'),
        ),
      );
    }
  }

  /// Abre el módulo y espera a que el listado de clientes termine de leer.
  ///
  /// La lectura se espera llamando a la misma función que hace la pantalla, en
  /// lugar de bombear un rato: cuánto tarda depende de la máquina.
  Future<void> abrirModulo(
    WidgetTester tester, {
    Size tamano = const Size(1400, 900),
  }) async {
    await tester.binding.setSurfaceSize(tamano);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CatalogosView())),
      ),
    );
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(CatalogosView)),
    );

    await contenedor.read(clientesViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  /// Una categoría con un concepto dentro, para el salto entre pestañas.
  Future<void> sembrarCategoriaConConcepto() async {
    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: const Value('Ropa de cama'),
        estatus: const Value(EstatusType.activo),
        diasEntrega: const Value(2),
      ),
    );

    await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion(
        categoriaId: Value(categoriaId),
        clotheSize: const Value(ClotheSizeType.king),
        nombreConcepto: const Value('Sábana'),
        diasEntrega: const Value(2),
        tipoUnidad: const Value(UnitType.pieza),
        importe: const Value(50),
        estatus: const Value(EstatusType.activo),
      ),
    );
  }

  /// Abre la pestaña de categorías y espera su lectura.
  Future<void> abrirCategorias(WidgetTester tester) async {
    await tester.tap(find.text('Categorías de ropa'));
    await tester.pumpAndSettle();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(CatalogosView)),
    );

    await contenedor.read(categoriasViewModelProvider.notifier).cargar();
    await tester.pumpAndSettle();
  }

  /// Escribe [texto] en el campo que lleva [etiqueta].
  ///
  /// El campo se busca por su etiqueta y no por su posición: un formulario al
  /// que se le agrega un campo no debería romper la prueba.
  Future<void> escribir(
    WidgetTester tester,
    String etiqueta,
    String texto,
  ) async {
    final campo = find.ancestor(
      of: find.text(etiqueta),
      matching: find.byType(TextField),
    );

    await tester.enterText(campo, texto);
    await tester.pump();
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  testWidgets('la tarjeta ocupa el espacio que deja la barra de pestañas', (
    tester,
  ) async {
    await sembrarClientes(3);
    await abrirModulo(tester);

    final modulo = tester.getRect(find.byType(CatalogosView));
    final barra = tester.getRect(find.byType(TabBar));
    final tarjeta = tester.getRect(
      find.descendant(
        of: find.byType(ListadoCatalogo),
        matching: find.byType(Card),
      ),
    );

    // Pegada a las orillas del módulo salvo por su propio margen...
    const margen = 12.0;
    expect(tarjeta.left, modulo.left + margen);
    expect(tarjeta.right, modulo.right - margen);
    expect(tarjeta.bottom, modulo.bottom - margen);

    // ...y empezando justo debajo de la barra, con la línea que la separa.
    const separador = 1.0;
    expect(tarjeta.top, barra.bottom + separador + margen);
  });

  testWidgets('el encabezado lleva el nombre del catálogo y el botón', (
    tester,
  ) async {
    await sembrarClientes(3);
    await abrirModulo(tester);

    final encabezado = tester.getRect(
      find.byKey(DataTableCard.llaveEncabezado),
    );
    final filtros = tester.getRect(find.byKey(DataTableCard.llaveFiltros));

    // El nombre de la pestaña, otra vez en la tarjeta...
    final titulo = tester.getRect(
      find.descendant(
        of: find.byKey(DataTableCard.llaveEncabezado),
        matching: find.text('Clientes'),
      ),
    );
    // ...y el botón de agregar enfrente, en el mismo renglón.
    final agregar = tester.getRect(
      find.widgetWithText(FilledButton, 'Agregar cliente'),
    );

    expect(encabezado.contains(titulo.center), isTrue);
    expect(encabezado.contains(agregar.center), isTrue);
    expect(agregar.left, greaterThan(titulo.right));

    // La línea del encabezado cierra el bloque, por encima de los filtros.
    final linea = tester.getRect(
      find.descendant(
        of: find.byKey(DataTableCard.llaveEncabezado),
        matching: find.byType(Divider),
      ),
    );

    expect(linea.top, greaterThan(agregar.bottom));
    expect(linea.bottom, lessThanOrEqualTo(filtros.top));
  });

  testWidgets('el buscador va con los demás filtros, arriba de la tabla', (
    tester,
  ) async {
    await sembrarClientes(3);
    await abrirModulo(tester);

    final tabla = tester.getRect(find.byType(DataTable));
    final filtros = tester.getRect(find.byKey(DataTableCard.llaveFiltros));

    expect(filtros.bottom, lessThan(tabla.top));

    final buscador = tester.getRect(
      find.widgetWithText(TextField, 'Buscar cliente'),
    );
    // (el desplegable pinta su etiqueta dos veces —la del campo y la del menú
    // desplegado—, así que basta con la primera)
    final orden = tester.getRect(find.text('Ordenar por').first);

    expect(filtros.contains(buscador.center), isTrue);
    expect(filtros.contains(orden.center), isTrue);
  });

  testWidgets('la paginación va entre los filtros y la tabla', (tester) async {
    await sembrarClientes(12);
    await abrirModulo(tester);

    final filtros = tester.getRect(find.byKey(DataTableCard.llaveFiltros));
    final paginacion = tester.getRect(
      find.byKey(DataTableCard.llavePaginacion),
    );
    final lista = tester.getRect(find.byKey(DataTableCard.llaveLista));

    // Los tres bloques, separados por el mismo aire: 1.5 rem.
    const aire = 24.0;
    expect(paginacion.top - filtros.bottom, aire);
    expect(lista.top - paginacion.bottom, aire);

    expect(find.text('Mostrando 1-10 de 12'), findsOneWidget);

    // La página trae diez de los doce. El orden de omisión es por fecha de
    // creación descendente, así que arriba está el último capturado.
    expect(find.text('Cliente 12'), findsOneWidget);
    expect(find.text('Cliente 2'), findsNothing);
  });

  testWidgets('la página siguiente trae el resto de los clientes', (
    tester,
  ) async {
    await sembrarClientes(12);
    await abrirModulo(tester);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 11-12 de 12'), findsOneWidget);
    expect(find.text('Cliente 2'), findsOneWidget);
    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Cliente 12'), findsNothing);
  });

  testWidgets('cada pestaña abre su catálogo', (tester) async {
    await sembrarClientes(1);
    await abrirModulo(tester);

    expect(find.text('Agregar cliente'), findsOneWidget);

    await abrirCategorias(tester);

    expect(find.text('Agregar categoría'), findsOneWidget);
    expect(find.text('Agregar cliente'), findsNothing);
    // El catálogo vacío lo dice en lugar de dejar una tabla con encabezados.
    expect(find.text('Todavía no hay categorías de ropa.'), findsOneWidget);
  });

  testWidgets('el cliente capturado aparece en la tabla al guardar', (
    tester,
  ) async {
    await abrirModulo(tester);

    expect(find.text('Todavía no hay clientes registrados.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Agregar cliente'));
    await tester.pumpAndSettle();

    await escribir(tester, 'Nombre(s)', 'Ana');
    await escribir(tester, 'Apellido(s)', 'Ramírez');
    await escribir(tester, 'Teléfono', '5512345678');

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));

    // Sin `pumpAndSettle` de aquí en adelante: mientras se guarda gira un
    // indicador, y el aviso de que salió bien trae una animación en bucle, así
    // que esa espera no terminaría nunca.
    await tester.pump();
    // La escritura y la relectura van contra una base de verdad, así que se
    // dejan terminar fuera del reloj falso de la prueba: dentro de él nada
    // asíncrono avanza mientras no se bombee un fotograma.
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El aviso de que salió bien, y detrás el renglón nuevo.
    expect(find.text('El cliente se registró correctamente.'), findsOneWidget);

    // El aviso de éxito sólo trae el botón de cerrar: no hay nada que aceptar.
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Mostrando 1-1 de 1'), findsOneWidget);
  });

  testWidgets('ver los conceptos de una categoría abre la pestaña de precios', (
    tester,
  ) async {
    await sembrarCategoriaConConcepto();
    await abrirModulo(tester);
    await abrirCategorias(tester);

    // La columna de acciones es la última de una tabla ancha, así que puede
    // quedar fuera de la parte visible: se trae antes de tocarla.
    final menu = find.byTooltip('Menú de acciones');
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();

    await tester.tap(menu);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver sus conceptos'));

    // Sin `pumpAndSettle`: el listado de precios nace leyendo, y su indicador
    // de carga no deja de girar.
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // La pestaña de precios, ya acotada a los conceptos de la categoría.
    expect(find.text('Agregar concepto'), findsOneWidget);
    expect(find.text('Sábana'), findsOneWidget);
    expect(find.text('Mostrando 1-1 de 1'), findsOneWidget);
  });

  testWidgets('en una ventana angosta nada se desborda', (tester) async {
    await sembrarClientes(3);
    await abrirModulo(tester, tamano: const Size(420, 800));

    expect(tester.takeException(), isNull);
    // A este ancho la tabla se cambia por las tarjetas de la vista compacta.
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Cliente 1'), findsOneWidget);
  });
}
