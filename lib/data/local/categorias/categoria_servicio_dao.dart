import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/shared/query_ordering.dart';
import 'package:gestion_lavanderia/data/local/shared/text_search.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/categorias/filtros_categoria.dart';
import 'package:gestion_lavanderia/models/tables/categorias/categoria_servicio.dart';

part 'categoria_servicio_dao.g.dart';

/// Acceso a las categorías de servicio.
///
/// Rige la misma invariante que en los precios: `estatus` decide la visibilidad
/// y `fechaEliminacion` sólo registra cuándo se dio de baja.
@DriftAccessor(tables: [CategoriaServicio])
class CategoriaServicioDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriaServicioDaoMixin {
  CategoriaServicioDao(super.db);

  Map<ColumnsCategoriaType, Expression<Object>> get _columnasOrdenables => {
    ColumnsCategoriaType.id: categoriaServicio.id,
    ColumnsCategoriaType.nombre: categoriaServicio.nombre,
    ColumnsCategoriaType.estatus: categoriaServicio.estatus,
    ColumnsCategoriaType.diasEntrega: categoriaServicio.diasEntrega,
    ColumnsCategoriaType.fechaCreacion: categoriaServicio.fechaCreacion,
    ColumnsCategoriaType.fechaEliminacion: categoriaServicio.fechaEliminacion,
  };

  Future<List<CategoriaServicioEntry>> getAll() {
    final query = select(categoriaServicio)
      ..where((t) => t.estatus.equals(EstatusType.activo.value))
      ..orderBy([(t) => OrderingTerm.asc(t.nombre)]);

    return query.get();
  }

  /// Listado de la pantalla de categorías, con los filtros ya aplicados.
  Future<List<CategoriaServicioEntry>> listado(FiltrosCategoria filtros) {
    final query = select(categoriaServicio);

    if (filtros.estatus != EstatusType.todos) {
      query.where((t) => t.estatus.equals(filtros.estatus.value));
    }

    if (filtros.nombre.isNotEmpty) {
      query.where((t) => likeAny(filtros.nombre, [t.nombre]));
    }

    query.orderByTerms(
      buildOrdering(
        ordenamiento: filtros.ordenamiento,
        columnas: _columnasOrdenables,
        ascendente: filtros.ascendente,
        desempate: categoriaServicio.id,
      ),
    );

    return query.get();
  }

  Future<CategoriaServicioEntry?> getById(int id) {
    final query = select(categoriaServicio)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> insertCategoria(CategoriaServicioCompanion row) async {
    await _ensureNombreUnico(row.nombre.value);

    return into(categoriaServicio).insert(
      row.copyWith(
        fechaCreacion: Value(DateTime.now()),
        fechaActualizacion: const Value(null),
      ),
    );
  }

  Future<bool> updateCategoria(CategoriaServicioEntry row) async {
    await _ensureNombreUnico(row.nombre, excluyendoId: row.id);

    return update(
      categoriaServicio,
    ).replace(row.copyWith(fechaActualizacion: Value(DateTime.now())));
  }

  /// Baja lógica: `estatus` y `fechaEliminacion` se escriben juntos.
  ///
  /// La baja en cascada de los conceptos de la categoría la coordina la capa
  /// superior con `PreciosConceptosDao.deactivatePreciosByCategoria`, para que
  /// ambas escrituras ocurran en una sola transacción.
  Future<bool> deleteCategoria(CategoriaServicioEntry row) {
    final now = DateTime.now();
    final updated = row.copyWith(
      estatus: EstatusType.inactivo.value,
      fechaEliminacion: Value(now),
      fechaActualizacion: Value(now),
    );

    return update(categoriaServicio).replace(updated);
  }

  /// Reactivar es lo inverso de [deleteCategoria]: `estatus` vuelve a activo y
  /// `fechaEliminacion` se limpia.
  Future<bool> activateCategoria(CategoriaServicioEntry row) {
    final updated = row.copyWith(
      estatus: EstatusType.activo.value,
      fechaEliminacion: const Value(null),
      fechaActualizacion: Value(DateTime.now()),
    );

    return update(categoriaServicio).replace(updated);
  }

  /// El nombre de una categoría es único, sin distinguir mayúsculas. Incluye
  /// las categorías inactivas, porque siguen existiendo en la tabla.
  Future<void> _ensureNombreUnico(String nombre, {int? excluyendoId}) async {
    final query = selectOnly(categoriaServicio)
      ..addColumns([categoriaServicio.id])
      ..where(categoriaServicio.nombre.lower().equals(nombre.toLowerCase()))
      ..limit(1);

    if (excluyendoId != null) {
      query.where(categoriaServicio.id.equals(excluyendoId).not());
    }

    if (await query.getSingleOrNull() == null) return;

    throw SQLException(
      message: 'Ya existe una categoría con el nombre "$nombre".',
    );
  }
}
