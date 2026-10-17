import 'dart:async';
import 'dart:convert';

import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
import 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los filtros con los que quedó cada listado, guardados en el equipo.
///
/// Cada módulo tiene una llave con su modelo de filtros serializado a JSON, así
/// que agregar un filtro nuevo es agregar un campo al modelo y no tocar esta
/// clase. Las enumeraciones viajan por el nombre de la constante y no por su
/// texto visible, para que cambiar una etiqueta de la interfaz no invalide lo
/// que ya está guardado.
///
/// Recibe la instancia de [SharedPreferences] ya resuelta —se obtiene de forma
/// asíncrona una sola vez al arrancar— para que las lecturas sean síncronas y
/// un listado no tenga que esperar dos veces.
class FiltrosStore {
  FiltrosStore(this._prefs);

  final SharedPreferences _prefs;

  static const _llaveCategorias = 'filtros_categorias';
  static const _llaveClientes = 'filtros_clientes';
  static const _llavePrecios = 'filtros_precios';
  static const _llaveOrdenes = 'filtros_ordenes';

  FiltrosCategoria get categorias => _leer(
    _llaveCategorias,
    FiltrosCategoria.fromJson,
    const FiltrosCategoria(),
  );

  FiltrosClientes get clientes =>
      _leer(_llaveClientes, FiltrosClientes.fromJson, const FiltrosClientes());

  FiltrosPrecios get precios =>
      _leer(_llavePrecios, FiltrosPrecios.fromJson, const FiltrosPrecios());

  FiltrosOrdenes get ordenes =>
      _leer(_llaveOrdenes, FiltrosOrdenes.fromJson, const FiltrosOrdenes());

  Future<void> guardarCategorias(FiltrosCategoria filtros) =>
      _guardar(_llaveCategorias, filtros.toJson());

  Future<void> guardarClientes(FiltrosClientes filtros) =>
      _guardar(_llaveClientes, filtros.toJson());

  Future<void> guardarPrecios(FiltrosPrecios filtros) =>
      _guardar(_llavePrecios, filtros.toJson());

  Future<void> guardarOrdenes(FiltrosOrdenes filtros) =>
      _guardar(_llaveOrdenes, filtros.toJson());

  /// Lee la llave y, si no hay nada guardado, devuelve [porOmision].
  ///
  /// Un JSON que ya no coincide con el modelo —una constante de ordenamiento
  /// que se renombró, por ejemplo— se descarta en lugar de dejar la pantalla
  /// inservible: se borra la llave y se vuelve a los filtros por omisión.
  T _leer<T>(
    String llave,
    T Function(Map<String, dynamic>) fromJson,
    T porOmision,
  ) {
    final texto = _prefs.getString(llave);
    if (texto == null) return porOmision;

    try {
      return fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      unawaited(_prefs.remove(llave));
      return porOmision;
    }
  }

  Future<void> _guardar(String llave, Map<String, dynamic> json) {
    return _prefs.setString(llave, jsonEncode(json));
  }
}
