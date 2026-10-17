import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba que el listado use los filtros guardados en el equipo y no los
/// por omisión, y que la baja de una categoría arrastre a sus conceptos en una
/// sola operación.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FiltrosStore store;
  late CategoriasLocalDatasource datasource;

  CategoriasLocalDatasource construir() => CategoriasLocalDatasource(
    db,
    db.categoriaServicioDao,
    db.preciosConceptosDao,
    store,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    store = FiltrosStore(await SharedPreferences.getInstance());
    datasource = construir();
  });

  tearDown(() => db.close());

  Future<int> crear(String nombre, {int diasEntrega = 1}) {
    return db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: nombre,
        estatus: EstatusType.activo,
        diasEntrega: diasEntrega,
        fechaCreacion: DateTime.now(),
      ),
    );
  }

  Future<int> crearConcepto(int categoriaId, {String nombre = 'Sábana'}) {
    return db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion.insert(
        categoriaId: categoriaId,
        clotheSize: ClotheSizeType.king,
        nombreConcepto: nombre,
        diasEntrega: 1,
        tipoUnidad: UnitType.pieza,
        importe: 50,
        estatus: EstatusType.activo,
        fechaCreacion: DateTime.now(),
      ),
    );
  }

  List<String> nombresDe(List<CategoriaServicioEntry> filas) {
    return filas.map((fila) => fila.nombre).toList();
  }

  test('por omisión lista sólo las categorías activas', () async {
    await crear('Planchado');
    await datasource.desactivar(await crear('Tintorería'));

    expect(nombresDe(await datasource.listado()), ['Planchado']);
  });

  test(
    'aplicarFiltros devuelve el listado y deja los filtros guardados',
    () async {
      await crear('Planchado');
      await datasource.desactivar(await crear('Tintorería'));

      final listado = await datasource.aplicarFiltros(
        const FiltrosCategoria(
          estatus: EstatusType.todos,
          ordenamiento: ColumnsCategoriaType.nombre,
          ascendente: true,
        ),
      );

      expect(nombresDe(listado), ['Planchado', 'Tintorería']);

      // Un datasource nuevo —otra pantalla, u otro arranque— ve los mismos
      // filtros sin que nadie se los pase.
      final otro = construir();
      expect(otro.filtros.estatus, EstatusType.todos);
      expect(nombresDe(await otro.listado()), ['Planchado', 'Tintorería']);
    },
  );

  test('el filtro por nombre no distingue mayúsculas', () async {
    await crear('Planchado');
    await crear('Ropa de cama');

    final listado = await datasource.aplicarFiltros(
      const FiltrosCategoria(nombre: 'PLANCH'),
    );

    expect(nombresDe(listado), ['Planchado']);
  });

  test('la categoría sale ya tipada: estatus no es un String', () async {
    final categoria = (await datasource.porId(await crear('Planchado')))!;

    expect(categoria.estatus, EstatusType.activo);
  });

  test('desactivar la categoría da de baja también sus conceptos', () async {
    final categoriaId = await crear('Ropa de cama');
    final precioId = await crearConcepto(categoriaId);

    await datasource.desactivar(categoriaId);

    final categoria = (await datasource.porId(categoriaId))!;
    final precio = (await db.preciosConceptosDao.getById(precioId))!.precio;

    expect(categoria.estatus, EstatusType.inactivo);
    expect(categoria.fechaEliminacion, isNotNull);
    expect(precio.estatus, EstatusType.inactivo);
    expect(precio.fechaEliminacion, isNotNull);
  });

  test('activar la categoría devuelve sus conceptos', () async {
    final categoriaId = await crear('Ropa de cama');
    final precioId = await crearConcepto(categoriaId);
    await datasource.desactivar(categoriaId);

    await datasource.activar(categoriaId);

    final categoria = (await datasource.porId(categoriaId))!;
    final precio = (await db.preciosConceptosDao.getById(precioId))!.precio;

    expect(categoria.estatus, EstatusType.activo);
    expect(categoria.fechaEliminacion, isNull);
    expect(precio.estatus, EstatusType.activo);
    expect(precio.fechaEliminacion, isNull);
  });

  test('guardar propaga los días de entrega a los conceptos', () async {
    final categoriaId = await crear('Ropa de cama');
    final precioId = await crearConcepto(categoriaId);

    await datasource.guardar(
      id: categoriaId,
      row: const CategoriaServicioCompanion(diasEntrega: Value(5)),
    );

    final precio = (await db.preciosConceptosDao.getById(precioId))!.precio;

    expect((await datasource.porId(categoriaId))!.diasEntrega, 5);
    expect(precio.diasEntrega, 5);
  });

  test('guardar sólo el nombre no toca los días de los conceptos', () async {
    final categoriaId = await crear('Ropa de cama', diasEntrega: 3);
    final precioId = await crearConcepto(categoriaId);

    await datasource.guardar(
      id: categoriaId,
      row: const CategoriaServicioCompanion(nombre: Value('Blancos')),
    );

    final categoria = (await datasource.porId(categoriaId))!;
    final precio = (await db.preciosConceptosDao.getById(precioId))!.precio;

    expect(categoria.nombre, 'Blancos');
    expect(
      categoria.diasEntrega,
      3,
      reason: 'la columna no venía en la escritura',
    );
    expect(precio.diasEntrega, 1, reason: 'el concepto conserva los suyos');
  });

  test(
    'un nombre duplicado deja la categoría y sus conceptos intactos',
    () async {
      final categoriaId = await crear('Ropa de cama');
      final precioId = await crearConcepto(categoriaId);
      await crear('Planchado');

      await expectLater(
        datasource.guardar(
          id: categoriaId,
          row: const CategoriaServicioCompanion(
            nombre: Value('Planchado'),
            diasEntrega: Value(9),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      final categoria = (await datasource.porId(categoriaId))!;
      final precio = (await db.preciosConceptosDao.getById(precioId))!.precio;

      expect(categoria.nombre, 'Ropa de cama');
      expect(categoria.diasEntrega, 1);
      expect(
        precio.diasEntrega,
        1,
        reason: 'la validación corre antes de cualquier escritura',
      );
    },
  );
}
