import 'package:gestion_lavanderia/data/local/clientes/cliente_dao.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_data_mapper.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';

export 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';

/// Los clientes, con los filtros que quedaron guardados en el equipo.
///
/// Lo que sale y entra es [ClienteData]: las filas de drift no salen de esta
/// capa, de modo que ninguna pantalla depende de cómo esté hecha la tabla.
///
/// Ninguna de sus escrituras toca más de una tabla, así que ninguna necesita
/// transacción. Las operaciones atómicas están en las categorías y las órdenes,
/// que sí escriben en varias.
class ClientesLocalDatasource {
  const ClientesLocalDatasource(this._dao, this._store);

  final ClientesDao _dao;
  final FiltrosStore _store;

  FiltrosClientes get filtros => _store.clientes;

  Future<List<ClienteData>> listado() async =>
      (await _dao.listado(_store.clientes)).toData();

  Future<List<ClienteData>> aplicarFiltros(FiltrosClientes filtros) async {
    await _store.guardarClientes(filtros);

    return (await _dao.listado(filtros)).toData();
  }

  Future<ClienteData?> porId(int id) async =>
      (await _dao.getById(id))?.toData();

  /// Para el buscador que elige el cliente de una orden.
  Future<List<ClienteData>> buscar(String info) async =>
      (await _dao.getClientesByInfo(info)).toData();

  /// Los clientes con orden más reciente, y si faltan, los registrados más
  /// recientemente. Ver `ClientesDao.getRecientes`.
  Future<List<ClienteData>> recientes({int limite = 8}) async =>
      (await _dao.getRecientes(limite)).toData();

  /// Guarda el cliente y devuelve su id: lo da de alta si es nuevo y lo
  /// actualiza si ya existía.
  ///
  /// La pantalla manda un [ClienteData] y aquí se traduce a la escritura con
  /// `toCompanion()`, que deja fuera las fechas de auditoría: las pone el DAO.
  Future<int> guardar(ClienteData cliente) async {
    final row = cliente.toCompanion();

    if (cliente.esNuevo) return _dao.insertCliente(row);

    await _dao.updateCliente(id: cliente.id, row: row);

    return cliente.id;
  }
}
