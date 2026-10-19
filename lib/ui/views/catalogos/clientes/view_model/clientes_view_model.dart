import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';
export 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';
export 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

part 'clientes_view_model.freezed.dart';
part 'clientes_view_model.g.dart';

@freezed
sealed class ClientesState with _$ClientesState {
  const ClientesState._();

  const factory ClientesState({
    /// El listado completo que devolvió la base con los filtros vigentes.
    @Default(Filas<ClienteData>()) Filas<ClienteData> clientes,
    @Default(FiltrosClientes()) FiltrosClientes filtros,
    @Default(Paginacion()) Paginacion paginacion,
    @Default(true) bool cargando,

    /// Lo último que falló. Vacío si no hay nada que avisar.
    @Default('') String mensajeError,
  }) = _ClientesState;

  /// Los clientes de la página que se está viendo, que es lo que recibe la
  /// tabla.
  List<ClienteData> get pagina => paginacion.recortar(clientes);
}

/// El listado de clientes y su alta y edición.
///
/// Cada escritura termina releyendo la lista: el listado no se arma a mano
/// agregando o quitando el renglón que cambió, porque el orden y los filtros
/// los decide la consulta y reproducirlos aquí sería una segunda versión de
/// las mismas reglas.
@riverpod
class ClientesViewModel extends _$ClientesViewModel {
  final _clientes = instance<ClientesLocalDatasource>();

  @override
  ClientesState build() {
    // La lectura arranca en una microtarea porque `build` tiene que devolver
    // el estado inicial sin esperar. Los filtros, en cambio, salen de una
    // lectura síncrona: son los que quedaron guardados en el equipo, y los
    // controles tienen que nacer pintados con ellos.
    Future.microtask(cargar);

    return ClientesState(filtros: _clientes.filtros);
  }

  /// Relee el listado con los filtros vigentes.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final clientes = await _clientes.listado();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        clientes: Filas(clientes),
        paginacion: state.paginacion.conTotal(clientes.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo leer la lista de clientes.');
    }
  }

  Future<void> buscar(String nombre) =>
      _aplicar(state.filtros.copyWith(nombre: nombre));

  Future<void> ordenar(ColumnClientesName columna, bool ascendente) {
    return _aplicar(
      state.filtros.copyWith(ordenamiento: columna, ascendente: ascendente),
    );
  }

  Future<void> limpiarFiltros() => _aplicar(const FiltrosClientes());

  void irAPagina(int pagina) {
    state = state.copyWith(paginacion: state.paginacion.conPagina(pagina));
  }

  void cambiarFilasPorPagina(int porPagina) {
    state = state.copyWith(
      paginacion: state.paginacion.conPorPagina(porPagina),
    );
  }

  /// Da de alta el cliente si es nuevo, y lo actualiza si ya existía.
  ///
  /// Devuelve si se pudo. Al fallar —un teléfono que ya es de otro cliente,
  /// por ejemplo— el motivo queda en [ClientesState.mensajeError] y el
  /// formulario se queda abierto para corregirlo.
  Future<bool> guardar(ClienteData cliente) {
    final limpio = cliente.copyWith(
      nombres: cliente.nombres.normalizeSpaces(),
      apellidos: cliente.apellidos.normalizeSpaces(),
      telefono: cliente.telefono.trim(),
      correo: cliente.correo.trim(),
    );

    return _escribir(
      () => _clientes.guardar(limpio),
      'No se pudo guardar el cliente.',
    );
  }

  /// Guarda los filtros y relee con ellos, de vuelta en la primera página:
  /// lo que se acaba de buscar rara vez está en la página 7 de lo anterior.
  Future<void> _aplicar(FiltrosClientes filtros) async {
    state = state.copyWith(filtros: filtros, cargando: true, mensajeError: '');

    try {
      final clientes = await _clientes.aplicarFiltros(filtros);

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        clientes: Filas(clientes),
        paginacion: state.paginacion.primera().conTotal(clientes.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo filtrar la lista de clientes.');
    }
  }

  /// Escribe y deja el listado al día.
  Future<bool> _escribir(Future<void> Function() accion, String siFalla) async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      await accion();

      if (!ref.mounted) return true;

      await cargar();

      return true;
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, siFalla);

      return false;
    }
  }

  /// Deja el error a la vista y lo manda a la consola.
  ///
  /// Al usuario se le dice qué no se pudo hacer; el detalle técnico va al log,
  /// porque un `toString` de una excepción de SQLite no le dice nada a quien
  /// atiende el mostrador.
  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    final detalle = error is SQLException ? error.message : mensaje;

    state = state.copyWith(cargando: false, mensajeError: detalle);
  }
}
