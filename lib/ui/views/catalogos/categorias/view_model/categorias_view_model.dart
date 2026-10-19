import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart'
    show preciosViewModelProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
export 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';
export 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

part 'categorias_view_model.freezed.dart';
part 'categorias_view_model.g.dart';

@freezed
sealed class CategoriasState with _$CategoriasState {
  const CategoriasState._();

  const factory CategoriasState({
    /// El listado completo que devolvió la base con los filtros vigentes.
    @Default(Filas<CategoriaData>()) Filas<CategoriaData> categorias,
    @Default(FiltrosCategoria()) FiltrosCategoria filtros,
    @Default(Paginacion()) Paginacion paginacion,
    @Default(true) bool cargando,
    @Default('') String mensajeError,
  }) = _CategoriasState;

  /// Las categorías de la página que se está viendo.
  List<CategoriaData> get pagina => paginacion.recortar(categorias);
}

/// El listado de categorías de ropa y su alta, edición y baja.
///
/// Una categoría arrastra a sus conceptos: al darla de baja se desactivan los
/// suyos, y al cambiarle los días de entrega los hereda cada uno. Por eso toda
/// escritura de aquí invalida además el listado de precios, que si está a la
/// vista en la otra pestaña se quedaría mostrando lo de antes.
@riverpod
class CategoriasViewModel extends _$CategoriasViewModel {
  final _categorias = instance<CategoriasLocalDatasource>();

  @override
  CategoriasState build() {
    Future.microtask(cargar);

    return CategoriasState(filtros: _categorias.filtros);
  }

  /// Relee el listado con los filtros vigentes.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final categorias = await _categorias.listado();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        categorias: Filas(categorias),
        paginacion: state.paginacion.conTotal(categorias.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron leer las categorías.');
    }
  }

  Future<void> buscar(String nombre) =>
      _aplicar(state.filtros.copyWith(nombre: nombre));

  Future<void> filtrarEstatus(EstatusType? estatus) =>
      _aplicar(state.filtros.copyWith(estatus: estatus));

  Future<void> ordenar(ColumnsCategoriaType columna, bool ascendente) {
    return _aplicar(
      state.filtros.copyWith(ordenamiento: columna, ascendente: ascendente),
    );
  }

  Future<void> limpiarFiltros() => _aplicar(FiltrosCategoria.porOmision);

  void irAPagina(int pagina) {
    state = state.copyWith(paginacion: state.paginacion.conPagina(pagina));
  }

  void cambiarFilasPorPagina(int porPagina) {
    state = state.copyWith(
      paginacion: state.paginacion.conPorPagina(porPagina),
    );
  }

  /// Da de alta una categoría, o guarda los cambios de [id] si viene.
  ///
  /// Los días de entrega viajan siempre, también al editar: el datasource los
  /// propaga a los conceptos de la categoría dentro de la misma transacción,
  /// porque los días de un concepto son los de su categoría. Quien edita ya lo
  /// aceptó en el formulario.
  /// Da de alta la categoría si es nueva, y la actualiza si ya existía.
  ///
  /// [propagarDias] decide si sus conceptos siguen a la categoría cuando le
  /// cambian los días de entrega. Lo pregunta el formulario, que es donde se
  /// ve el cambio; aquí sólo se pasa.
  Future<bool> guardar(CategoriaData categoria, {bool propagarDias = true}) {
    final limpia = categoria.copyWith(
      nombre: categoria.nombre.normalizeSpaces(),
    );

    return _escribir(
      () => _categorias.guardar(limpia, propagarDias: propagarDias),
      'No se pudo guardar la categoría.',
    );
  }

  /// Cuántos conceptos cuelgan de la categoría, para decirlo al preguntar si
  /// un cambio de días los alcanza.
  Future<int> conceptosDe(int id) => _categorias.conceptos(id);

  /// Da de baja la categoría y, con ella, sus conceptos vigentes.
  Future<bool> desactivar(int id) => _escribir(
    () => _categorias.desactivar(id),
    'No se pudo desactivar la categoría.',
  );

  /// Reactiva la categoría y los conceptos que tenía dados de baja.
  Future<bool> activar(int id) => _escribir(
    () => _categorias.activar(id),
    'No se pudo activar la categoría.',
  );

  Future<void> _aplicar(FiltrosCategoria filtros) async {
    state = state.copyWith(filtros: filtros, cargando: true, mensajeError: '');

    try {
      final categorias = await _categorias.aplicarFiltros(filtros);

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        categorias: Filas(categorias),
        paginacion: state.paginacion.primera().conTotal(categorias.length),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudieron filtrar las categorías.');
    }
  }

  /// Escribe, deja el listado al día y avisa al de precios.
  ///
  /// El aviso es un `invalidate` y no una recarga directa: si nadie está
  /// mirando los precios, el provider ni siquiera existe y no hay nada que
  /// releer; cuando se abra esa pestaña nacerá con lo que haya en la base.
  Future<bool> _escribir(Future<void> Function() accion, String siFalla) async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      await accion();

      if (!ref.mounted) return true;

      await cargar();
      ref.invalidate(preciosViewModelProvider);

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
