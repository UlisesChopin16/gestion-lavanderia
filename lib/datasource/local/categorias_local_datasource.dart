import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/categorias/categoria_servicio_dao.dart';
import 'package:gestion_lavanderia/data/local/precios/precios_conceptos_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';

/// Las categorías y lo que arrastran consigo.
///
/// El DAO sólo sabe de SQL y recibe los filtros ya resueltos; de dónde salen y
/// quién los guarda se decide aquí. Aquí viven además las operaciones que tocan
/// más de una tabla, porque un DAO no puede coordinar a otro.
///
/// Las lecturas devuelven `CategoriaServicioEntry`, la fila generada: una
/// categoría no tiene más forma que su fila y la columna `estatus` ya sale como
/// `EstatusType`, así que la interfaz la puede consumir tal cual. Los modelos
/// propios —`PrecioData`, `OrdenDetalleData`— están donde la forma del dominio
/// sí difiere de la tabla.
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

  Future<List<CategoriaServicioEntry>> listado() =>
      _dao.listado(_store.categorias);

  /// Las categorías activas, para los selectores que piden una.
  Future<List<CategoriaServicioEntry>> activas() => _dao.getAll();

  /// Todas, activas o no, para los filtros: un listado se puede acotar a una
  /// categoría que ya se dio de baja.
  Future<List<CategoriaServicioEntry>> todas() => _dao.getTodas();

  Future<CategoriaServicioEntry?> porId(int id) => _dao.getById(id);

  /// Guarda los filtros y devuelve el listado ya filtrado: sin stream que
  /// reaccione solo, cambiar un filtro y recargar la lista es una sola llamada.
  Future<List<CategoriaServicioEntry>> aplicarFiltros(
    FiltrosCategoria filtros,
  ) async {
    await _store.guardarCategorias(filtros);
    return _dao.listado(filtros);
  }

  Future<int> crear(CategoriaServicioCompanion row) =>
      _dao.insertCategoria(row);

  /// Guarda la categoría y propaga sus días de entrega a sus conceptos.
  ///
  /// Las dos escrituras van en una transacción porque los días de entrega de un
  /// concepto son los de su categoría: si la segunda falla, la categoría
  /// prometería una fecha que sus conceptos no respetan. La propagación sólo
  /// ocurre cuando el companion trae esa columna, para que editar el nombre no
  /// reescriba todos los conceptos.
  Future<void> guardar({
    required int id,
    required CategoriaServicioCompanion row,
  }) {
    return _db.transaction(() async {
      await _dao.updateCategoria(id: id, row: row);

      if (!row.diasEntrega.present) return;

      await _precios.changeDiasPreciosByCategoria(
        categoriaId: id,
        diasEntrega: row.diasEntrega.value,
      );
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
