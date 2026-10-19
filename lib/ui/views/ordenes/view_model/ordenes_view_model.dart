import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/ordenes/filtros_ordenes.dart';
export 'package:gestion_lavanderia/models/data/ordenes/orden_listado_data.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';
export 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

part 'ordenes_view_model.freezed.dart';
part 'ordenes_view_model.g.dart';

@freezed
sealed class OrdenesState with _$OrdenesState {
  const OrdenesState._();

  const factory OrdenesState({
    /// El listado completo que devolvió la base con los filtros vigentes.
    @Default(Filas<OrdenListadoData>()) Filas<OrdenListadoData> ordenes,
    @Default(FiltrosOrdenes()) FiltrosOrdenes filtros,
    @Default(Paginacion()) Paginacion paginacion,
    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _OrdenesState;

  /// Las órdenes de la página que se está viendo.
  List<OrdenListadoData> get pagina => paginacion.recortar(ordenes);

  /// El rango de creación tal como lo entiende el calendario: vacío cuando no
  /// se filtra por fechas, con una sola cuando el rango está abierto por un
  /// extremo y con dos cuando está completo.
  List<DateTime?> get rangoCreacion => [
    ?filtros.fechaInicio,
    ?filtros.fechaFin,
  ];
}

/// El listado de órdenes de servicio.
///
/// Sólo lee: filtra, ordena y pagina lo que la base devuelve. Lo que mueve una
/// orden —darla de alta, abonar, entregar ropa— vive en los diálogos que abre
/// la pantalla, y cada uno pedirá su relectura con [cargar] al terminar.
///
/// El filtrado no se hace en memoria sobre lo ya leído: cada cambio vuelve a
/// consultar, porque el listado une tres tablas —la orden, su cliente y su
/// último movimiento— y las condiciones por fecha, estatus y método de pago
/// las resuelve la base mejor que un `where` sobre la lista.
@riverpod
class OrdenesViewModel extends _$OrdenesViewModel {
  final _ordenes = instance<OrdenesLocalDatasource>();

  @override
  OrdenesState build() {
    Future.microtask(cargar);

    // Los filtros con los que se cerró la aplicación la última vez: el
    // datasource los guarda en el equipo, así que la pantalla nace con ellos
    // puestos y la primera lectura ya los aplica.
    return OrdenesState(filtros: _ordenes.filtros);
  }

  /// Relee el listado con los filtros vigentes.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final ordenes = await _ordenes.listado();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        ordenes: Filas(ordenes),
        paginacion: state.paginacion.conTotal(ordenes.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron leer las órdenes.');
    }
  }

  /// Busca por folio y por nombre del cliente a la vez: es lo que se tiene a
  /// mano cuando alguien llega a recoger su ropa, con el ticket o sin él.
  Future<void> buscar(String texto) =>
      _aplicar(state.filtros.copyWith(busqueda: texto));

  /// `null` es no filtrar por estatus, que en los filtros se guarda como
  /// [EstatusOrdenType.todos] porque es lo que la base sabe leer.
  Future<void> filtrarEstatus(EstatusOrdenType? estatus) {
    return _aplicar(
      state.filtros.copyWith(estatus: estatus ?? EstatusOrdenType.todos),
    );
  }

  Future<void> filtrarMetodoPago(MetodoPagoType? metodoPago) =>
      _aplicar(state.filtros.copyWith(metodoPago: metodoPago));

  /// Acota el listado por fecha de creación.
  ///
  /// Recibe la lista del calendario tal cual: con una sola fecha el rango
  /// queda abierto por el final —de ese día en adelante—, que es lo que la
  /// consulta ya sabe resolver, y no hay que esperar a que el rango esté
  /// completo para empezar a ver resultados.
  Future<void> filtrarFechas(List<DateTime?> fechas) {
    return _aplicar(
      state.filtros.copyWith(
        fechaInicio: fechas.elementAtOrNull(0),
        fechaFin: fechas.elementAtOrNull(1),
      ),
    );
  }

  Future<void> quitarFechas() =>
      _aplicar(state.filtros.copyWith(fechaInicio: null, fechaFin: null));

  Future<void> ordenar(ColumnsOrdenesNames columna, bool ascendente) {
    return _aplicar(
      state.filtros.copyWith(ordenamiento: columna, ascendente: ascendente),
    );
  }

  Future<void> limpiarFiltros() => _aplicar(const FiltrosOrdenes());

  void irAPagina(int pagina) {
    state = state.copyWith(paginacion: state.paginacion.conPagina(pagina));
  }

  void cambiarFilasPorPagina(int porPagina) {
    state = state.copyWith(
      paginacion: state.paginacion.conPorPagina(porPagina),
    );
  }

  Future<void> _aplicar(FiltrosOrdenes filtros) async {
    state = state.copyWith(filtros: filtros, cargando: true, mensajeError: '');

    try {
      final ordenes = await _ordenes.aplicarFiltros(filtros);

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        ordenes: Filas(ordenes),
        paginacion: state.paginacion.primera().conTotal(ordenes.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron filtrar las órdenes.');
    }
  }

  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    final detalle = error is SQLException ? error.message : mensaje;

    state = state.copyWith(cargando: false, mensajeError: detalle);
  }
}
