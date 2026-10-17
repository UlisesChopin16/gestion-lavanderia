import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba que el listado use los filtros guardados en el equipo y no los
/// por omisión.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FiltrosStore store;
  late CategoriasLocalDatasource datasource;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    store = FiltrosStore(await SharedPreferences.getInstance());
    datasource = CategoriasLocalDatasource(db.categoriaServicioDao, store);
  });

  tearDown(() => db.close());

  Future<CategoriaServicioEntry> crear(String nombre) async {
    final id = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: nombre,
        estatus: EstatusType.activo.value,
        diasEntrega: 1,
        fechaCreacion: DateTime.now(),
      ),
    );

    return (await db.categoriaServicioDao.getById(id))!;
  }

  List<String> nombresDe(List<CategoriaServicioEntry> filas) {
    return filas.map((fila) => fila.nombre).toList();
  }

  test('por omisión lista sólo las categorías activas', () async {
    await crear('Planchado');
    await db.categoriaServicioDao.deleteCategoria(await crear('Tintorería'));

    expect(nombresDe(await datasource.listado()), ['Planchado']);
  });

  test('aplicarFiltros devuelve el listado y deja los filtros guardados',
      () async {
    await crear('Planchado');
    await db.categoriaServicioDao.deleteCategoria(await crear('Tintorería'));

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
    final otro = CategoriasLocalDatasource(db.categoriaServicioDao, store);
    expect(otro.filtros.estatus, EstatusType.todos);
    expect(nombresDe(await otro.listado()), ['Planchado', 'Tintorería']);
  });

  test('el filtro por nombre no distingue mayúsculas', () async {
    await crear('Planchado');
    await crear('Ropa de cama');

    final listado = await datasource.aplicarFiltros(
      const FiltrosCategoria(nombre: 'PLANCH'),
    );

    expect(nombresDe(listado), ['Planchado']);
  });
}
