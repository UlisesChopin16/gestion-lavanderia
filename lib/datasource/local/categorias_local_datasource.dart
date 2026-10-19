import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/categorias/categoria_data_mapper.dart';
import 'package:gestion_lavanderia/data/local/categorias/categoria_servicio_dao.dart';
import 'package:gestion_lavanderia/data/local/precios/precios_conceptos_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';

export 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';

/// Las categorías y lo que arrastran consigo.
///
/// El DAO sólo sabe de SQL y recibe los filtros ya resueltos; de dónde salen y
/// quién los guarda se decide aquí. Aquí viven además las operaciones que tocan
/// más de una tabla, porque un DAO no puede coordinar a otro.
///
/// Lo que sale y entra es [CategoriaData]: las filas de drift no salen de esta
/// capa, de modo que ninguna pantalla depende de cómo esté hecha la tabla.
class CategoriasLocalDatasource {
  const CategoriasLocalDatasource(
    this._db,
    this._dao,
    this._precios,
    this._store,
  );

  final AppDatabase _db;
  final CategoriaServicioDao _dao;
  final PreciosConceptosDao _precios;
  final FiltrosStore _store;

  /// Los filtros vigentes, para pintar los controles con lo último que se usó.
  FiltrosCategoria get filtros => _store.categorias;

  Future<List<CategoriaData>> listado() async =>
      (await _dao.listado(_store.categorias)).toData();

  /// Las categorías activas, para los selectores que piden una.
  Future<List<CategoriaData>> activas() async => (await _dao.getAll()).toData();

  /// Todas, activas o no, para los filtros: un listado se puede acotar a una
  /// categoría que ya se dio de baja.
  Future<List<CategoriaData>> todas() async => (await _dao.getTodas()).toData();

  Future<CategoriaData?> porId(int id) async =>
      (await _dao.getById(id))?.toData();

  /// Cuántos conceptos cuelgan de la categoría, para avisar del alcance de un
  /// cambio antes de hacerlo.
  Future<int> conceptos(int id) => _precios.contarPorCategoria(id);

  /// Guarda los filtros y devuelve el listado ya filtrado: sin stream que
  /// reaccione solo, cambiar un filtro y recargar la lista es una sola llamada.
  Future<List<CategoriaData>> aplicarFiltros(FiltrosCategoria filtros) async {
    await _store.guardarCategorias(filtros);

    return (await _dao.listado(filtros)).toData();
  }

  /// Guarda la categoría y devuelve su id: la da de alta si es nueva y la
  /// actualiza si ya existía. Al cambiarle los días de entrega se los propaga
  /// a sus conceptos.
  ///
  /// Las dos escrituras van en una transacción porque los días de entrega de un
  /// concepto son los de su categoría: si la segunda falla, la categoría
  /// prometería una fecha que sus conceptos no respetan.
  ///
  /// La propagación sólo ocurre cuando ese número cambió de verdad, y para
  /// saberlo se lee antes la categoría como está guardada: editar el nombre no
  /// tiene por qué reescribir todos sus conceptos.
  ///
  /// Con [propagarDias] en `false` la categoría cambia sola y sus conceptos
  /// conservan los días que tengan: hay conceptos que se apartan de su
  /// categoría a propósito, y renumerar la categoría no debería borrar esa
  /// decisión. Quien llama es la pantalla, que es la que lo preguntó.
  Future<int> guardar(CategoriaData categoria, {bool propagarDias = true}) {
    return _db.transaction(() async {
      final row = categoria.toCompanion();

      if (categoria.esNueva) return _dao.insertCategoria(row);

      final actual = await _dao.getById(categoria.id);

      await _dao.updateCategoria(id: categoria.id, row: row);

      if (propagarDias &&
          actual != null &&
          actual.diasEntrega != categoria.diasEntrega) {
        await _precios.changeDiasPreciosByCategoria(
          categoriaId: categoria.id,
          diasEntrega: categoria.diasEntrega,
        );
      }

      return categoria.id;
    });
  }

  /// Da de baja la categoría y, con ella, sus conceptos vigentes.
  ///
  /// Es la operación que el DAO no puede hacer solo. En una transacción y en
  /// este orden: la categoría primero, porque la baja de los conceptos busca los
  /// que todavía no tienen fecha de eliminación. Sin la transacción, una
  /// categoría inactiva podría quedar con conceptos activos, y la pantalla de
  /// precios los ofrecería para cobrar.
  Future<void> desactivar(int id) {
    return _db.transaction(() async {
      await _dao.deleteCategoria(id);
      await _precios.deactivatePreciosByCategoria(id);
    });
  }

  /// Reactiva la categoría y sus conceptos dados de baja.
  ///
  /// Lo inverso de [desactivar], con una salvedad: reactiva *todos* los
  /// conceptos de la categoría que tengan fecha de eliminación, no sólo los que
  /// se dieron de baja en cascada. Un concepto desactivado a mano antes de
  /// desactivar la categoría vuelve a quedar activo.
  Future<void> activar(int id) {
    return _db.transaction(() async {
      await _dao.activateCategoria(id);
      await _precios.activatePreciosByCategoria(id);
    });
  }
}
