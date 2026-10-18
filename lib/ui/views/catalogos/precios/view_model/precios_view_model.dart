import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/data/local/app_database.dart'
    show CategoriaServicioEntry;
export 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
export 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';
export 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

part 'precios_view_model.freezed.dart';
part 'precios_view_model.g.dart';

@freezed
sealed class PreciosState with _$PreciosState {
  const PreciosState._();

  const factory PreciosState({
    /// El listado completo que devolvió la base con los filtros vigentes.
    @Default(Filas<PrecioData>()) Filas<PrecioData> precios,

    /// Las categorías, para el filtro y para el formulario. Van todas y no
    /// sólo las activas porque la lista se puede acotar a una categoría dada
    /// de baja, para ver qué conceptos se fueron con ella.
    @Default(Filas<CategoriaServicioEntry>())
    Filas<CategoriaServicioEntry> categorias,
    @Default(FiltrosPrecios()) FiltrosPrecios filtros,
    @Default(Paginacion()) Paginacion paginacion,
    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _PreciosState;

  /// Los conceptos de la página que se está viendo.
  List<PrecioData> get pagina => paginacion.recortar(precios);

  /// Las categorías a las que se puede asignar un concepto. La base rechaza
  /// un concepto en una categoría dada de baja, así que el formulario sólo
  /// ofrece las vigentes.
  List<CategoriaServicioEntry> get categoriasActivas => categorias
      .where((categoria) => categoria.estatus == EstatusType.activo)
      .toList();

  /// Si se puede dar de alta un concepto. Sin categorías vigentes no hay
  /// dónde ponerlo, y el formulario pediría elegir una de una lista vacía.
  bool get puedeAgregar => categoriasActivas.isNotEmpty;
}

/// El listado de conceptos de precio y su alta, edición y baja.
///
/// Carga también las categorías activas porque las necesita para dos cosas: el
/// filtro por categoría y el formulario del concepto. Van en la misma lectura
/// que los precios para que no puedan quedar desfasadas —una categoría recién
/// dada de baja seguiría ofreciéndose— y porque es una consulta local y corta.
@riverpod
class PreciosViewModel extends _$PreciosViewModel {
  final _precios = instance<PreciosLocalDatasource>();
  final _categorias = instance<CategoriasLocalDatasource>();

  @override
  PreciosState build() {
    Future.microtask(cargar);

    return PreciosState(filtros: _precios.filtros);
  }

  /// Relee el listado y las categorías con los filtros vigentes.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final precios = await _precios.listado();
      final categorias = await _categorias.todas();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        precios: Filas(precios),
        categorias: Filas(categorias),
        paginacion: state.paginacion.conTotal(precios.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron leer los conceptos.');
    }
  }

  Future<void> buscar(String nombre) =>
      _aplicar(state.filtros.copyWith(nombre: nombre));

  Future<void> filtrarEstatus(EstatusType? estatus) =>
      _aplicar(state.filtros.copyWith(estatus: estatus));

  /// Deja a la vista sólo los conceptos de [categoriaId].
  ///
  /// Lo usa también la pantalla de categorías, para ver de un salto los
  /// conceptos de una de ellas. Como el filtro se guarda en el equipo, la
  /// pestaña de precios lo recoge aunque todavía no se haya abierto.
  ///
  /// [incluirInactivos] es para llegar desde una categoría dada de baja: sus
  /// conceptos se desactivaron con ella, así que con el filtro de estatus en
  /// "activo" —el de omisión— la lista saldría vacía.
  Future<void> filtrarPorCategoria(
    int categoriaId, {
    bool incluirInactivos = false,
  }) {
    return _aplicar(
      state.filtros.copyWith(
        categoriaId: categoriaId,
        estatus: incluirInactivos ? null : state.filtros.estatus,
      ),
    );
  }

  /// Quita el filtro por categoría.
  Future<void> quitarCategoria() =>
      _aplicar(state.filtros.copyWith(categoriaId: sinCategoria));

  Future<void> filtrarTamano(ClotheSizeType? tamano) =>
      _aplicar(state.filtros.copyWith(clotheSize: tamano));

  Future<void> ordenar(ColumnPreciosName columna, bool ascendente) {
    return _aplicar(
      state.filtros.copyWith(ordenamiento: columna, ascendente: ascendente),
    );
  }

  Future<void> limpiarFiltros() => _aplicar(FiltrosPrecios.porOmision);

  void irAPagina(int pagina) {
    state = state.copyWith(paginacion: state.paginacion.conPagina(pagina));
  }

  void cambiarFilasPorPagina(int porPagina) {
    state = state.copyWith(
      paginacion: state.paginacion.conPorPagina(porPagina),
    );
  }

  /// Da de alta el concepto si es nuevo, y lo actualiza si ya existía.
  ///
  /// Que no haya dos conceptos iguales —misma categoría, mismo tamaño, mismo
  /// nombre— lo revisa la base al escribir, y su negativa llega aquí como el
  /// mensaje que ve el usuario.
  Future<bool> guardar(PrecioData precio) {
    final limpio = precio.copyWith(
      nombreConcepto: precio.nombreConcepto.normalizeSpaces(),
    );

    return _escribir(
      () => _precios.guardar(limpio),
      'No se pudo guardar el concepto.',
    );
  }

  Future<bool> desactivar(int id) => _escribir(
    () => _precios.desactivar(id),
    'No se pudo desactivar el concepto.',
  );

  Future<bool> activar(int id) =>
      _escribir(() => _precios.activar(id), 'No se pudo activar el concepto.');

  Future<void> _aplicar(FiltrosPrecios filtros) async {
    state = state.copyWith(filtros: filtros, cargando: true, mensajeError: '');

    try {
      final precios = await _precios.aplicarFiltros(filtros);

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        precios: Filas(precios),
        paginacion: state.paginacion.primera().conTotal(precios.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron filtrar los conceptos.');
    }
  }

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

  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    final detalle = error is SQLException ? error.message : mensaje;

    state = state.copyWith(cargando: false, mensajeError: detalle);
  }
}
