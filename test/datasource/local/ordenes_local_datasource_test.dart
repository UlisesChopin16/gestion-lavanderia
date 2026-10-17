import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba las operaciones atómicas de las órdenes: que las escrituras que
/// tocan varias tablas queden completas o no queden, y que el saldo y el
/// estatus se deriven siempre de la misma regla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late OrdenesLocalDatasource ordenes;
  late PreciosLocalDatasource precios;
  late int clienteId;
  late PrecioData sabana;

  /// Un renglón de ropa del concepto [precio], con entrega en dos días.
  ItemOrdenData renglon(PrecioData precio, {double cantidad = 1}) {
    return ItemOrdenData(
      precio: precio,
      cantidad: cantidad,
      fechaEntrega: DateTime(2026, 10, 19),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final store = FiltrosStore(await SharedPreferences.getInstance());

    ordenes = OrdenesLocalDatasource(
      db,
      db.ordenServicioDao,
      db.ordenHistoryDao,
      db.itemServicioOrdenDao,
      db.clientesDao,
      store,
    );
    precios = PreciosLocalDatasource(db.preciosConceptosDao, store);

    clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );

    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: 'Ropa de cama',
        estatus: EstatusType.activo,
        diasEntrega: 2,
        fechaCreacion: DateTime.now(),
      ),
    );

    final precioId = await precios.guardar(
      PrecioData(
        categoriaId: categoriaId,
        categoria: 'Ropa de cama',
        nombreConcepto: 'Sábana',
        clotheSize: ClotheSizeType.king,
        diasEntrega: 2,
        tipoUnidad: UnitType.pieza,
        importe: 50,
      ),
    );

    sabana = (await precios.porId(precioId))!;
  });

  tearDown(() => db.close());

  group('crearOrden', () {
    test('deja la orden, su ropa y su primer movimiento', () async {
      final orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana), renglon(sabana)],
      );

      expect(orden.folio, isNotEmpty);
      expect(orden.cliente, 'Ana López');
      expect(orden.items, hasLength(2));
      expect(orden.historial, hasLength(1));
      expect(orden.historial.single.huboEntrega, isFalse);
      expect(orden.pendientesPorEntregar, 2);
    });

    test('el total sale del precio y la cantidad, no de la pantalla', () async {
      final orden = await ordenes.crearOrden(
        clienteId: clienteId,
        // Un importe inventado: el datasource lo recalcula.
        items: [renglon(sabana, cantidad: 3).copyWith(importe: 7)],
      );

      expect(orden.items.single.importe, 150);
      expect(orden.total, 150);
      expect(orden.importeDeItems, orden.total);
    });

    test('con abono parcial queda en curso y con saldo', () async {
      final orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana, cantidad: 2)],
        abono: 40,
        metodoPago: MetodoPagoType.tarjeta,
      );

      expect(orden.total, 100);
      expect(orden.restante, 60);
      expect(orden.pagado, 40);
      expect(orden.estatus, EstatusOrdenType.enCurso);
      expect(orden.historial.single.metodoPago, MetodoPagoType.tarjeta);
    });

    test('pagada de golpe pero sin entregar queda en pagado', () async {
      final orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
        abono: 50,
      );

      expect(orden.restante, 0);
      expect(orden.estatus, EstatusOrdenType.pagado);
      expect(orden.fechaCierre, isNull, reason: 'todavía falta entregar');
    });

    test('una orden sin ropa no se crea', () async {
      await expectLater(
        ordenes.crearOrden(clienteId: clienteId, items: const []),
        throwsA(isA<Exception>()),
      );

      expect(await ordenes.listado(), isEmpty);
    });

    test('un abono mayor que el total no se acepta', () async {
      await expectLater(
        ordenes.crearOrden(
          clienteId: clienteId,
          items: [renglon(sabana)],
          abono: 80,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await ordenes.listado(), isEmpty);
    });

    test('si la ropa no se puede insertar, la orden tampoco queda', () async {
      // El concepto no existe: la orden entra y el `INSERT` de la ropa viola la
      // clave ajena. Es el caso que la transacción tiene que deshacer.
      final fantasma = sabana.copyWith(id: 999999);

      await expectLater(
        ordenes.crearOrden(clienteId: clienteId, items: [renglon(fantasma)]),
        throwsA(isA<Exception>()),
      );

      expect(await ordenes.listado(), isEmpty);
      expect(
        await db.ordenHistoryDao.getHistoryByOrden(1),
        isEmpty,
        reason: 'ni la orden ni su movimiento sobrevivieron',
      );
    });
  });

  group('registrarMovimiento', () {
    test('abona, entrega y recalcula en una sola operación', () async {
      var orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana), renglon(sabana)],
      );

      orden = await ordenes.registrarMovimiento(
        ordenId: orden.id,
        monto: 50,
        itemsAEntregar: [orden.items.first.id],
      );

      expect(orden.restante, 50);
      expect(orden.estatus, EstatusOrdenType.enCurso);
      expect(orden.pendientesPorEntregar, 1);
      expect(orden.historial, hasLength(2));

      final ultimo = orden.ultimoMovimiento!;
      expect(ultimo.monto, 50);
      expect(ultimo.restante, 50);
      expect(ultimo.entregados, hasLength(1));
      expect(ultimo.entregados.single.precio.nombreConcepto, 'Sábana');
    });

    test('se puede entregar sin abonar', () async {
      var orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
      );

      orden = await ordenes.registrarMovimiento(
        ordenId: orden.id,
        itemsAEntregar: [orden.items.single.id],
      );

      expect(orden.restante, 50, reason: 'el saldo no se movió');
      expect(orden.pendientesPorEntregar, 0);
      expect(orden.ultimoMovimiento!.huboAbono, isFalse);
      expect(orden.ultimoMovimiento!.huboEntrega, isTrue);
    });

    test('pagar y entregar todo cierra la orden con su fecha', () async {
      var orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
      );

      orden = await ordenes.registrarMovimiento(
        ordenId: orden.id,
        monto: 50,
        itemsAEntregar: [orden.items.single.id],
      );

      expect(orden.restante, 0);
      expect(orden.todoEntregado, isTrue);
      expect(orden.estatus, EstatusOrdenType.cerrada);
      expect(orden.fechaCierre, isNotNull);
    });

    test('una orden cerrada ya no admite movimientos', () async {
      var orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
      );
      orden = await ordenes.registrarMovimiento(
        ordenId: orden.id,
        monto: 50,
        itemsAEntregar: [orden.items.single.id],
      );

      await expectLater(
        ordenes.registrarMovimiento(ordenId: orden.id, monto: 10),
        throwsA(isA<Exception>()),
      );
    });

    test('un abono mayor que el saldo no deja movimiento', () async {
      final orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
      );

      await expectLater(
        ordenes.registrarMovimiento(ordenId: orden.id, monto: 500),
        throwsA(isA<Exception>()),
      );

      final despues = (await ordenes.detalle(orden.id))!;
      expect(despues.restante, 50);
      expect(despues.historial, hasLength(1));
    });
  });

  group('agregarItems', () {
    test('recalcula el total y reabre la orden pagada', () async {
      var orden = await ordenes.crearOrden(
        clienteId: clienteId,
        items: [renglon(sabana)],
        abono: 50,
      );
      expect(orden.estatus, EstatusOrdenType.pagado);

      orden = await ordenes.agregarItems(
        ordenId: orden.id,
        items: [renglon(sabana, cantidad: 2)],
      );

      expect(orden.items, hasLength(2));
      expect(orden.total, 150);
      expect(orden.restante, 100);
      expect(orden.estatus, EstatusOrdenType.enCurso);
      expect(orden.importeDeItems, orden.total);
    });
  });

  test('el detalle anida la ropa y el historial de la orden', () async {
    var orden = await ordenes.crearOrden(
      clienteId: clienteId,
      items: [renglon(sabana), renglon(sabana)],
    );
    orden = await ordenes.registrarMovimiento(
      ordenId: orden.id,
      monto: 30,
      itemsAEntregar: [orden.items.first.id],
    );

    final detalle = (await ordenes.detalle(orden.id))!;

    // La forma que consume la pantalla: la orden arriba, y dentro la ropa y los
    // movimientos, cada movimiento con lo que salió en él.
    expect(detalle.cliente, 'Ana López');
    expect(detalle.clienteTelefono, '5551234567');
    expect(detalle.items.first.precio.categoria, 'Ropa de cama');
    expect(detalle.items.first.concepto, 'Sábana - Tamaño King');
    expect(detalle.historial.map((m) => m.entregados.length), [1, 0]);
  });

  test('el listado trae el método de pago del último movimiento', () async {
    final orden = await ordenes.crearOrden(
      clienteId: clienteId,
      items: [renglon(sabana)],
      metodoPago: MetodoPagoType.efectivo,
    );
    await ordenes.registrarMovimiento(
      ordenId: orden.id,
      monto: 50,
      metodoPago: MetodoPagoType.transferencia,
    );

    final renglones = await ordenes.listado();

    expect(renglones, hasLength(1));
    expect(renglones.single.metodoPago, MetodoPagoType.transferencia);
    expect(renglones.single.cliente, 'Ana López');
    expect(renglones.single.restante, 0);
  });
}
