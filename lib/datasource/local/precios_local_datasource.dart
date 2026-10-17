import 'package:gestion_lavanderia/data/local/precios/precios_conceptos_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';

/// Listado de conceptos de precio con los filtros que quedaron guardados en el
/// equipo.
class PreciosLocalDatasource {
  const PreciosLocalDatasource(this._dao, this._store);

  final PreciosConceptosDao _dao;
  final FiltrosStore _store;

  FiltrosPrecios get filtros => _store.precios;

  Future<List<PrecioConDetallesEntry>> listado() =>
      _dao.listado(filtros: _store.precios);

  /// Conceptos de una sola categoría, para el diálogo que los elige dentro de
  /// una orden. No guarda nada: la categoría la impone la pantalla y no es una
  /// elección del usuario que convenga recordar.
  Future<List<PrecioConDetallesEntry>> listadoPorCategoria(int categoriaId) {
    return _dao.listadoPorCategoria(
      categoriaId: categoriaId,
      filtros: _store.precios,
    );
  }

  Future<List<PrecioConDetallesEntry>> aplicarFiltros(
    FiltrosPrecios filtros,
  ) async {
    await _store.guardarPrecios(filtros);
    return _dao.listado(filtros: filtros);
  }
}
