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
///
/// Las lecturas devuelven la fila generada y las escrituras reciben un
/// companion con el id aparte. Una categoría no tiene más forma que su fila, así
/// que `CategoriaServicioEntry` es el modelo que viaja hasta la interfaz: un
/// gemelo campo por campo sólo agregaría un mapeo que el compilador no puede
/// verificar.
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
      ..where((t) => t.estatus.equalsValue(EstatusType.activo))
      ..orderBy([(t) => OrderingTerm.asc(t.nombre)]);

    return query.get();
  }

  /// Listado de la pantalla de categorías, con los filtros ya aplicados.
  Future<List<CategoriaServicioEntry>> listado(FiltrosCategoria filtros) {
    final query = select(categoriaServicio);

    if (filtros.estatus != EstatusType.todos) {
      query.where((t) => t.estatus.equalsValue(filtros.estatus));
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

  /// Escribe sobre la categoría [id] las columnas que traiga [row]; las que
  /// vengan ausentes se quedan como están.
  ///
  /// Recibe un companion y el id en lugar de la fila completa para que quien
  /// llama arme la escritura con lo que cambió, sin reconstruir las columnas de
  /// auditoría que no muestra ninguna pantalla.
  Future<void> updateCategoria({
    required int id,
    required CategoriaServicioCompanion row,
  }) async {
    if (row.nombre.present) {
      await _ensureNombreUnico(row.nombre.value, excluyendoId: id);
    }

    await _escribir(
      id,
      row.copyWith(fechaActualizacion: Value(DateTime.now())),
    );
  }

  /// Baja lógica: `estatus` y `fechaEliminacion` se escriben juntos.
  ///
  /// La baja en cascada de los conceptos de la categoría la coordina
  /// `CategoriasLocalDatasource.desactivar`, que llama a este método y a
  /// `PreciosConceptosDao.deactivatePreciosByCategoria` dentro de una sola
  /// transacción.
  Future<void> deleteCategoria(int id) {
    final now = DateTime.now();

    return _escribir(
      id,
      CategoriaServicioCompanion(
        estatus: const Value(EstatusType.inactivo),
        fechaEliminacion: Value(now),
        fechaActualizacion: Value(now),
      ),
    );
  }

  /// Reactivar es lo inverso de [deleteCategoria]: `estatus` vuelve a activo y
  /// `fechaEliminacion` se limpia.
  Future<void> activateCategoria(int id) {
    return _escribir(
      id,
      CategoriaServicioCompanion(
        estatus: const Value(EstatusType.activo),
        fechaEliminacion: const Value(null),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );
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

  /// Escribe sobre la fila [id].
  ///
  /// El id y la fecha de creación se descartan vengan o no en el companion: son
  /// las dos columnas que una actualización nunca debe tocar.
  Future<void> _escribir(int id, CategoriaServicioCompanion row) async {
    final statement = update(categoriaServicio)..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
      ),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'La categoría que se intentó actualizar ya no existe.',
    );
  }
}
