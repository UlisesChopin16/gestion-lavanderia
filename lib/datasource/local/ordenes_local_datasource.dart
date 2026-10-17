import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';

/// Listado de órdenes con los filtros que quedaron guardados en el equipo.
///
/// El listado vive en [OrdenHistoryDao] porque cada renglón muestra la orden
/// junto con su último movimiento de pago.
class OrdenesLocalDatasource {
  const OrdenesLocalDatasource(this._dao, this._store);

  final OrdenHistoryDao _dao;
  final FiltrosStore _store;

  FiltrosOrdenes get filtros => _store.ordenes;

  Future<List<OrdenConDetallesEntry>> listado() => _dao.listado(_store.ordenes);

  Future<List<OrdenConDetallesEntry>> aplicarFiltros(
    FiltrosOrdenes filtros,
  ) async {
    await _store.guardarOrdenes(filtros);
    return _dao.listado(filtros);
  }
}
