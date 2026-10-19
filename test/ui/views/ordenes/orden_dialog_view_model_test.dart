import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/view_model/orden_dialog_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba cómo se arma una orden antes de escribirla: qué catálogo se
/// ofrece, cómo se suman las prendas, qué cuentas salen de ellas y qué queda
/// en la base al guardar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  OrdenDialogViewModel notificador() =>
      container.read(ordenDialogViewModelProvider.notifier);

  OrdenDialogState estado() => container.read(ordenDialogViewModelProvider);

  Future<int> crearCategoria({String nombre = 'Ropa de cama'}) {
    return db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: Value(nombre),
        estatus: const Value(EstatusType.activo),
        diasEntrega: const Value(2),
      ),
    );
  }

  Future<void> crearConcepto({
    required int categoriaId,
    String nombre = 'Sábana',
    double importe = 50,
    int diasEntrega = 2,
    EstatusType estatus = EstatusType.activo,
  }) async {
    final id = await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion(
        categoriaId: Value(categoriaId),
        clotheSize: const Value(ClotheSizeType.emptySize),
        nombreConcepto: Value(nombre),
        diasEntrega: Value(diasEntrega),
        tipoUnidad: const Value(UnitType.pieza),
        importe: Value(importe),
        estatus: Value(estatus),
      ),
    );

    if (estatus == EstatusType.inactivo) {
      await db.preciosConceptosDao.deletePrecio(id);
    }
  }

  Future<int> crearCliente({
    String nombres = 'Ana',
    String telefono = '5551234567',
  }) {
    return db.clientesDao.insertCliente(
      ClienteCompanion(
        nombres: Value(nombres),
        apellidos: const Value('Pérez'),
        telefono: Value(telefono),
        correo: Value('${nombres.toLowerCase()}@correo.com'),
      ),
    );
  }

  /// El concepto del catálogo que se llama [nombre]. Es como lo elige la
  /// pantalla: tocando el renglón que lo muestra.
  PrecioData concepto(String nombre) =>
      estado().conceptos.firstWhere((p) => p.nombreConcepto == nombre);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  group('el catálogo', () {
    test('ofrece sólo los conceptos vigentes', () async {
      final categoriaId = await crearCategoria();
      await crearConcepto(categoriaId: categoriaId, nombre: 'Sábana');
      await crearConcepto(
        categoriaId: categoriaId,
        nombre: 'Cobija',
        estatus: EstatusType.inactivo,
      );

      await notificador().cargar();

      expect(estado().conceptos.map((precio) => precio.nombreConcepto), [
        'Sábana',
      ]);
    });

    test('el buscador y la categoría acotan lo que se ve', () async {
      final cama = await crearCategoria(nombre: 'Ropa de cama');
      final fina = await crearCategoria(nombre: 'Ropa fina');
      await crearConcepto(categoriaId: cama, nombre: 'Sábana');
      await crearConcepto(categoriaId: fina, nombre: 'Camisa');

      await notificador().cargar();

      expect(estado().conceptosVisibles, hasLength(2));

      notificador().buscarConcepto('cami');

      expect(
        estado().conceptosVisibles.map((precio) => precio.nombreConcepto),
        ['Camisa'],
      );

      notificador().buscarConcepto('');
      notificador().filtrarCategoria(cama);

      expect(
        estado().conceptosVisibles.map((precio) => precio.nombreConcepto),
        ['Sábana'],
      );

      notificador().filtrarCategoria(sinCategoria);

      expect(estado().conceptosVisibles, hasLength(2));
    });
  });

  group('la ropa de la orden', () {
    setUp(() async {
      final categoriaId = await crearCategoria();
      await crearConcepto(
        categoriaId: categoriaId,
        nombre: 'Sábana',
        importe: 50,
        diasEntrega: 2,
      );
      await crearConcepto(
        categoriaId: categoriaId,
        nombre: 'Cobija',
        importe: 120,
      );

      await notificador().cargar();
    });

    test('agregar el mismo concepto suma cantidad', () async {
      notificador().agregar(concepto('Sábana'));
      notificador().agregar(concepto('Sábana'));

      final items = estado().items;

      expect(items, hasLength(1));
      expect(items.single.cantidad, 2);
      expect(estado().total, 100);
      expect(estado().cantidadDe(concepto('Sábana')), 2);
    });

    test('la entrega sale de los días que pide el concepto', () async {
      notificador().agregar(concepto('Sábana'));

      final hoy = DateTime.now();
      final esperada = DateTime(hoy.year, hoy.month, hoy.day + 2);

      expect(estado().items.single.fechaEntrega, esperada);
      expect(estado().entregaEstimada, esperada);
    });

    test('la entrega de un renglón se puede correr', () async {
      notificador().agregar(concepto('Sábana'));

      final manana = DateTime.now().add(const Duration(days: 1));
      notificador().cambiarEntrega(0, manana);

      expect(estado().items.single.fechaEntrega, manana);
    });

    test('bajar de una unidad quita el renglón', () async {
      notificador().agregar(concepto('Sábana'));
      notificador().cambiarCantidad(0, 0);

      expect(estado().items, isEmpty);
      expect(estado().total, 0);
    });

    test('el total suma todos los renglones', () async {
      notificador().agregar(concepto('Sábana'));
      notificador().cambiarCantidad(0, 3);
      notificador().agregar(concepto('Cobija'));

      expect(estado().total, 270);
      expect(estado().items, hasLength(2));

      notificador().quitar(1);

      expect(estado().total, 150);
    });
  });

  group('el cobro', () {
    setUp(() async {
      final categoriaId = await crearCategoria();
      await crearConcepto(categoriaId: categoriaId, importe: 50);

      await notificador().cargar();
      notificador().agregar(concepto('Sábana'));
    });

    test('el abono no pasa del total ni baja de cero', () async {
      notificador().cambiarAbono(500);

      expect(estado().abono, 50);
      expect(estado().resta, 0);

      notificador().cambiarAbono(-10);

      expect(estado().abono, 0);
      expect(estado().resta, 50);
    });

    test('quitar ropa recorta el abono al total nuevo', () async {
      notificador().abonarTodo();

      expect(estado().abono, 50);

      notificador().quitar(0);

      expect(estado().abono, 0);
    });
  });

  group('el cliente', () {
    test('se busca por teléfono y se elige', () async {
      await crearCliente(nombres: 'Lucía', telefono: '5559998888');
      await crearCliente(nombres: 'Mario', telefono: '5551112222');

      await notificador().buscarCliente('5559998888');

      expect(estado().encontrados, hasLength(1));

      notificador().elegirCliente(estado().encontrados.first);

      expect(estado().cliente?.nombres, 'Lucía');

      notificador().quitarCliente();

      expect(estado().cliente, isNull);
    });

    test('con el buscador vacío no se lista a nadie', () async {
      await crearCliente();

      await notificador().buscarCliente('');

      expect(estado().encontrados, isEmpty);
    });

    test('tras registrar a uno nuevo queda elegido', () async {
      await notificador().buscarCliente('Lucía');

      expect(estado().encontrados, isEmpty);

      // Lo que hace el diálogo de alta, que corre aparte.
      await crearCliente(nombres: 'Lucía', telefono: '5550001111');

      await notificador().repetirBusquedaDeCliente();

      expect(estado().cliente?.nombres, 'Lucía');
    });
  });

  group('al guardar', () {
    setUp(() async {
      final categoriaId = await crearCategoria();
      await crearConcepto(categoriaId: categoriaId, importe: 50);

      await notificador().cargar();
    });

    test('sin cliente o sin ropa no se puede', () async {
      expect(estado().puedeGuardar, isFalse);

      notificador().agregar(concepto('Sábana'));

      expect(estado().puedeGuardar, isFalse);

      final clienteId = await crearCliente();
      final cliente = await instance<ClientesLocalDatasource>().porId(
        clienteId,
      );
      notificador().elegirCliente(cliente!);

      expect(estado().puedeGuardar, isTrue);
    });

    test('la orden queda en la base con su ropa y su abono', () async {
      final clienteId = await crearCliente(nombres: 'Lucía');
      final cliente = await instance<ClientesLocalDatasource>().porId(
        clienteId,
      );

      notificador().elegirCliente(cliente!);
      notificador().agregar(concepto('Sábana'));
      notificador().cambiarCantidad(0, 2);
      notificador().elegirMetodoPago(MetodoPagoType.tarjeta);
      notificador().cambiarAbono(40);
      notificador().cambiarDescripcion('  Una mancha de café  ');

      expect(await notificador().guardar(), isTrue);

      final ordenes = await instance<OrdenesLocalDatasource>().listado();
      final orden = ordenes.single;

      expect(orden.cliente, 'Lucía Pérez');
      expect(orden.total, 100);
      expect(orden.restante, 60);
      expect(orden.metodoPago, MetodoPagoType.tarjeta);
      expect(orden.estatus, EstatusOrdenType.enCurso);
      // La nota se guarda sin los espacios de los lados.
      expect(orden.descripcion, 'Una mancha de café');

      final detalle = await instance<OrdenesLocalDatasource>().detalle(
        orden.id,
      );

      expect(detalle?.items, hasLength(1));
      expect(detalle?.items.single.cantidad, 2);
    });

    test('pagada completa nace como pagada', () async {
      final clienteId = await crearCliente();
      final cliente = await instance<ClientesLocalDatasource>().porId(
        clienteId,
      );

      notificador().elegirCliente(cliente!);
      notificador().agregar(concepto('Sábana'));
      notificador().abonarTodo();

      expect(await notificador().guardar(), isTrue);

      final orden = (await instance<OrdenesLocalDatasource>().listado()).single;

      expect(orden.restante, 0);
      expect(orden.estatus, EstatusOrdenType.pagado);
    });
  });
}
