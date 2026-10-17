import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/categorias/categoria_servicio_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';

/// Listado de categorías con los filtros que quedaron guardados en el equipo.
///
/// El DAO sólo sabe de SQL y recibe los filtros ya resueltos; de dónde salen y
/// quién los guarda se decide aquí.
class CategoriasLocalDatasource {
  const CategoriasLocalDatasource(this._dao, this._store);

  final CategoriaServicioDao _dao;
  final FiltrosStore _store;

  /// Los filtros vigentes, para pintar los controles con lo último que se usó.
  FiltrosCategoria get filtros => _store.categorias;

  Future<List<CategoriaServicioEntry>> listado() =>
      _dao.listado(_store.categorias);

  /// Guarda los filtros y devuelve el listado ya filtrado: sin stream que
  /// reaccione solo, cambiar un filtro y recargar la lista es una sola llamada.
  Future<List<CategoriaServicioEntry>> aplicarFiltros(
    FiltrosCategoria filtros,
  ) async {
    await _store.guardarCategorias(filtros);
    return _dao.listado(filtros);
  }
}
