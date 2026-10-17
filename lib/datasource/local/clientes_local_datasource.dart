import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';

/// Listado de clientes con los filtros que quedaron guardados en el equipo.
class ClientesLocalDatasource {
  const ClientesLocalDatasource(this._dao, this._store);

  final ClientesDao _dao;
  final FiltrosStore _store;

  FiltrosClientes get filtros => _store.clientes;

  Future<List<ClienteEntry>> listado() => _dao.listado(_store.clientes);

  Future<List<ClienteEntry>> aplicarFiltros(FiltrosClientes filtros) async {
    await _store.guardarClientes(filtros);
    return _dao.listado(filtros);
  }
}
