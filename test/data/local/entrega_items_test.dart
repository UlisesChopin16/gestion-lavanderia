import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba que la entrega de ropa quede ligada al movimiento del historial
/// en el que ocurrió.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late OrdenesLocalDatasource datasource;
  late int ordenId;
  late List<int> itemIds;

  /// Cada orden de prueba necesita su propio cliente: dos clientes no pueden
  /// compartir correo ni teléfono.
  var contador = 0;

  /// Una orden con tres items sin entregar y su primer movimiento.
  Future<int> primerMovimiento() async {
    contador++;
    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana$contador@example.com',
        telefono: '555123456$contador',
        fechaCreacion: DateTime.now(),
      ),
    );

    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: 'Ropa de cama $contador',
        estatus: EstatusType.activo,
        diasEntrega: 2,
        fechaCreacion: DateTime.now(),
      ),
    );

    final precioId = await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion.insert(
        categoriaId: categoriaId,
        clotheSize: ClotheSizeType.king,
        nombreConcepto: 'Sábana',
        diasEntrega: 2,
        tipoUnidad: UnitType.pieza,
        importe: 50,
        estatus: EstatusType.activo,
        fechaCreacion: DateTime.now(),
      ),
    );

    final orden = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.enCurso,
        total: 150,
        restante: 150,
        fechaCreacion: DateTime.now(),
      ),
    );
    ordenId = orden.id;

    for (var i = 0; i < 3; i++) {
      await db.itemServicioOrdenDao.insertItem(
        ItemServicioOrdenCompanion.insert(
          ordenId: ordenId,
          precioConceptoId: precioId,
          cantidad: 1,
          importe: 50,
          fechaEntrega: DateTime.now().add(const Duration(days: 2)),
          fechaCreacion: DateTime.now(),
        ),
      );
    }

    itemIds = (await db.itemServicioOrdenDao.getItemsByOrden(ordenId))
        .map((entry) => entry.item.id)
        .toList();

    return db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: ordenId,
        monto: 0,
        restante: 150,
        metodoPago: MetodoPagoType.efectivo,
        fecha: DateTime.now(),
      ),
    );
  }

  Future<int> movimiento(double monto, double restante) {
    return db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: ordenId,
        monto: monto,
        restante: restante,
        metodoPago: MetodoPagoType.efectivo,
        fecha: DateTime.now(),
      ),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    contador = 0;
    datasource = OrdenesLocalDatasource(
      db,
      db.ordenServicioDao,
      db.ordenHistoryDao,
      db.itemServicioOrdenDao,
      db.clientesDao,
      FiltrosStore(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() => db.close());

  test('sin entregas, el historial no trae items', () async {
    await primerMovimiento();

    final historial = await datasource.historial(ordenId);

    expect(historial, hasLength(1));
    expect(historial.single.huboEntrega, isFalse);
    expect(await datasource.pendientesPorEntregar(ordenId), 3);
  });

  test('cada movimiento trae la ropa que se entregó en él', () async {
    final primero = await primerMovimiento();
    final fechaPrimero = DateTime.now();

    await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: [itemIds.first],
      ordenHistoryId: primero,
      fecha: fechaPrimero,
    );

    final segundo = await movimiento(100, 50);
    await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: itemIds.sublist(1),
      ordenHistoryId: segundo,
      fecha: DateTime.now(),
    );

    final historial = await datasource.historial(ordenId);
    final porId = {for (final renglon in historial) renglon.id: renglon};

    expect(porId[primero]!.entregados.map((e) => e.id), [itemIds.first]);
    expect(porId[segundo]!.entregados.map((e) => e.id), itemIds.sublist(1));
    expect(await datasource.pendientesPorEntregar(ordenId), 0);
  });

  test('la entrega marca el item, su fecha y el movimiento', () async {
    final primero = await primerMovimiento();
    // Sin milisegundos: la base guarda las fechas como segundos Unix.
    final fecha = DateTime(2026, 10, 17, 9, 30);

    final entregados = await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: [itemIds.first],
      ordenHistoryId: primero,
      fecha: fecha,
    );

    expect(entregados, 1);

    final items = await db.itemServicioOrdenDao.getItemsByOrden(ordenId);
    final entregado = items.first.item;

    expect(entregado.estaEntregado, isTrue);
    expect(entregado.ordenHistoryId, primero);
    expect(entregado.fechaEntregado, fecha);
    expect(items.last.item.estaEntregado, isFalse);
    expect(items.last.item.ordenHistoryId, isNull);
  });

  test('un item ya entregado no se pasa a otro movimiento', () async {
    final primero = await primerMovimiento();
    await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: itemIds,
      ordenHistoryId: primero,
      fecha: DateTime.now(),
    );

    final segundo = await movimiento(150, 0);
    final reentregados = await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: itemIds,
      ordenHistoryId: segundo,
      fecha: DateTime.now(),
    );

    expect(reentregados, 0);

    final historial = await datasource.historial(ordenId);
    final porId = {for (final renglon in historial) renglon.id: renglon};

    expect(porId[primero]!.entregados, hasLength(3));
    expect(porId[segundo]!.entregados, isEmpty);
  });

  test('un item de otra orden no se entrega con esta', () async {
    final primero = await primerMovimiento();
    final ajenos = itemIds;
    final primeraOrden = ordenId;

    // Una segunda orden, con su propia ropa.
    await primerMovimiento();

    final entregados = await db.itemServicioOrdenDao.entregarItems(
      ordenId: ordenId,
      itemIds: ajenos,
      ordenHistoryId: primero,
      fecha: DateTime.now(),
    );

    expect(entregados, 0);
    expect(await datasource.pendientesPorEntregar(primeraOrden), 3);
  });
}
