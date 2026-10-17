import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_dao.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';

export 'package:gestion_lavanderia/data/local/clientes/cliente_extensions.dart';

/// Los clientes, con los filtros que quedaron guardados en el equipo.
///
/// Devuelve `ClienteEntry`, la fila generada: un cliente no tiene más forma que
/// su fila, así que no lleva modelo propio. Lo derivado —el nombre completo—
/// viaja en una extensión sobre la fila, que se re-exporta aquí para que la
/// pantalla no tenga que importarla aparte.
///
/// Ninguna de sus escrituras toca más de una tabla, así que ninguna necesita
/// transacción. Las operaciones atómicas están en las categorías y las órdenes,
/// que sí escriben en varias.
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

  Future<ClienteEntry?> porId(int id) => _dao.getById(id);

  /// Para el buscador que elige el cliente de una orden.
  Future<List<ClienteEntry>> buscar(String info) =>
      _dao.getClientesByInfo(info);

  Future<int> crear(ClienteCompanion row) => _dao.insertCliente(row);

  Future<void> guardar({required int id, required ClienteCompanion row}) =>
      _dao.updateCliente(id: id, row: row);
}
