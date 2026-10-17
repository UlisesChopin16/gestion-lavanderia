import 'package:gestion_lavanderia/data/local/precios/precio_data_mapper.dart';
import 'package:gestion_lavanderia/data/local/precios/precios_conceptos_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

export 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

/// Los conceptos de precio, con los filtros que quedaron guardados en el equipo.
///
/// Es la frontera donde la fila se vuelve modelo: el DAO devuelve el concepto y
/// su categoría como dos filas unidas, y aquí salen ya como [PrecioData], que es
/// la forma en que la interfaz lo muestra y lo edita. La interfaz no ve drift.
class PreciosLocalDatasource {
  const PreciosLocalDatasource(this._dao, this._store);

  final PreciosConceptosDao _dao;
  final FiltrosStore _store;

  FiltrosPrecios get filtros => _store.precios;

  Future<List<PrecioData>> listado() async {
    return (await _dao.listado(filtros: _store.precios)).toData();
  }

  /// Los conceptos activos, para armar una orden.
  Future<List<PrecioData>> activos() async => (await _dao.getAll()).toData();

  Future<PrecioData?> porId(int id) async => (await _dao.getById(id))?.toData();

  /// Conceptos de una sola categoría, para el diálogo que los elige dentro de
  /// una orden. No guarda nada: la categoría la impone la pantalla y no es una
  /// elección del usuario que convenga recordar.
  Future<List<PrecioData>> listadoPorCategoria(int categoriaId) async {
    final filas = await _dao.listadoPorCategoria(
      categoriaId: categoriaId,
      filtros: _store.precios,
    );

    return filas.toData();
  }

  Future<List<PrecioData>> aplicarFiltros(FiltrosPrecios filtros) async {
    await _store.guardarPrecios(filtros);
    return (await _dao.listado(filtros: filtros)).toData();
  }

  /// Guarda el concepto y devuelve su id: lo inserta si es nuevo y lo actualiza
  /// si ya existía.
  ///
  /// La pantalla manda un [PrecioData] y aquí se traduce a la escritura con
  /// `toCompanion()`, que deja fuera el nombre de la categoría —que es de otra
  /// tabla— y las fechas de auditoría, que las pone el DAO.
  Future<int> guardar(PrecioData precio) async {
    final row = precio.toCompanion();

    if (precio.esNuevo) return _dao.insertPrecio(row);

    await _dao.updatePrecio(id: precio.id, row: row);
    return precio.id;
  }

  /// Avisa si el concepto ya existe, antes de pedir confirmación al usuario.
  Future<void> verificarDuplicado(PrecioData precio) {
    return _dao.ensurePrecioUnico(precio.toCompanion());
  }

  Future<void> desactivar(int id) => _dao.deletePrecio(id);

  Future<void> activar(int id) => _dao.activatePrecio(id);
}
