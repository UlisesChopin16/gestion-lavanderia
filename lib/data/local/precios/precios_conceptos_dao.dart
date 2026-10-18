import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/precios/precio_con_detalles_entry.dart';
import 'package:gestion_lavanderia/data/local/shared/query_ordering.dart';
import 'package:gestion_lavanderia/data/local/shared/text_search.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:gestion_lavanderia/models/tables/precios/precios_conceptos.dart';

export 'package:gestion_lavanderia/data/local/precios/precio_con_detalles_entry.dart';

part 'precios_conceptos_dao.g.dart';

/// Acceso a los conceptos de precio.
///
/// Invariante de visibilidad: `estatus` es la única fuente de verdad sobre si
/// un concepto está vigente. `fechaEliminacion` registra *cuándo* se desactivó
/// y siempre se escribe junto con `estatus`; por eso las lecturas filtran por
/// `estatus` y no por la fecha.
@DriftAccessor(tables: [PreciosConceptos])
class PreciosConceptosDao extends DatabaseAccessor<AppDatabase>
    with _$PreciosConceptosDaoMixin {
  PreciosConceptosDao(super.db);

  /// Columnas por las que la lista de precios puede ordenarse.
  Map<ColumnPreciosName, Expression<Object>> get _columnasOrdenables => {
    ColumnPreciosName.id: preciosConceptos.id,
    ColumnPreciosName.nombre: preciosConceptos.nombreConcepto,
    ColumnPreciosName.categoria: categoriaServicio.nombre,
    ColumnPreciosName.sizeRopa: preciosConceptos.clotheSize,
    ColumnPreciosName.tipoUnidad: preciosConceptos.tipoUnidad,
    ColumnPreciosName.diasEntrega: preciosConceptos.diasEntrega,
    ColumnPreciosName.importe: preciosConceptos.importe,
    ColumnPreciosName.estatus: preciosConceptos.estatus,
    ColumnPreciosName.fechaCreacion: preciosConceptos.fechaCreacion,
    ColumnPreciosName.fechaEliminacion: preciosConceptos.fechaEliminacion,
  };

  Future<List<PrecioConDetallesEntry>> getAll() async {
    final query = _queryJoined()
      ..where(preciosConceptos.estatus.equalsValue(EstatusType.activo));

    return _toDetalles(await query.get());
  }

  /// Un concepto con su categoría, que es como lo necesita toda pantalla: el
  /// nombre de la categoría se muestra junto al del concepto.
  Future<PrecioConDetallesEntry?> getById(int id) async {
    final query = _queryJoined()..where(preciosConceptos.id.equals(id));
    final fila = await query.getSingleOrNull();

    if (fila == null) return null;
    return PrecioConDetallesEntry.fromRow(fila, attachedDatabase);
  }

  /// Listado de la pantalla de precios, con los filtros ya aplicados.
  Future<List<PrecioConDetallesEntry>> listado({
    required FiltrosPrecios filtros,
  }) async {
    return _toDetalles(await _queryFiltrado(filtros).get());
  }

  /// Listado restringido a una categoría, para el diálogo que elige
  /// conceptos dentro de una orden.
  ///
  /// Fija la categoría *en los filtros* en lugar de agregar un segundo
  /// `where`: si los filtros de la pantalla ya traen otra categoría, las dos
  /// condiciones se contradicen y el listado sale vacío.
  Future<List<PrecioConDetallesEntry>> listadoPorCategoria({
    required int categoriaId,
    required FiltrosPrecios filtros,
  }) {
    return listado(filtros: filtros.copyWith(categoriaId: categoriaId));
  }

  Future<int> insertPrecio(PreciosConceptosCompanion row) async {
    await _ensureCategoriaActiva(
      categoriaId: row.categoriaId.value,
      nombreConcepto: row.nombreConcepto.value,
      accion: 'crear',
    );
    await ensurePrecioUnico(row);

    return into(preciosConceptos).insert(
      row.copyWith(
        fechaCreacion: Value(DateTime.now()),
        fechaActualizacion: const Value(null),
      ),
    );
  }

  /// Escribe sobre el concepto [id] las columnas que traiga [row].
  ///
  /// Las reglas se verifican contra la fila *como quedará*: el companion puede
  /// traer sólo lo que cambió, así que lo ausente se toma de la fila actual.
  /// Sin esa mezcla, editar únicamente el importe compararía la unicidad contra
  /// una categoría y un nombre que nadie mandó.
  Future<void> updatePrecio({
    required int id,
    required PreciosConceptosCompanion row,
  }) async {
    final actual = await _filaActual(id);

    final categoriaId = row.categoriaId.present
        ? row.categoriaId.value
        : actual.categoriaId;
    final clotheSize = row.clotheSize.present
        ? row.clotheSize.value
        : actual.clotheSize;
    final nombreConcepto = row.nombreConcepto.present
        ? row.nombreConcepto.value
        : actual.nombreConcepto;

    await _ensureCategoriaActiva(
      categoriaId: categoriaId,
      nombreConcepto: nombreConcepto,
      accion: 'actualizar',
    );
    await _ensureUnico(
      categoriaId: categoriaId,
      clotheSize: clotheSize,
      nombreConcepto: nombreConcepto,
      excluyendoId: id,
    );

    await _escribir(
      id,
      row.copyWith(fechaActualizacion: Value(DateTime.now())),
    );
  }

  /// Baja lógica de un concepto: escribe `estatus` y `fechaEliminacion` en la
  /// misma operación para que no puedan quedar desalineados.
  Future<void> deletePrecio(int id) {
    final now = DateTime.now();

    return _escribir(
      id,
      PreciosConceptosCompanion(
        estatus: const Value(EstatusType.inactivo),
        fechaEliminacion: Value(now),
        fechaActualizacion: Value(now),
      ),
    );
  }

  /// Reactiva un concepto: lo inverso de [deletePrecio].
  ///
  /// Un concepto no puede volver sin su categoría. Reactivarlo dentro de una
  /// categoría inactiva lo dejaría cobrable en una categoría que no lo está, y
  /// es la misma regla que impide crearlo o editarlo ahí.
  Future<void> activatePrecio(int id) async {
    final actual = await _filaActual(id);

    await _ensureCategoriaActiva(
      categoriaId: actual.categoriaId,
      nombreConcepto: actual.nombreConcepto,
      accion: 'activar',
    );

    return _escribir(
      id,
      PreciosConceptosCompanion(
        estatus: const Value(EstatusType.activo),
        fechaEliminacion: const Value(null),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );
  }

  /// Reactiva en una sola sentencia los conceptos dados de baja junto con su
  /// categoría.
  Future<int> activatePreciosByCategoria(int categoriaId) {
    final statement = update(preciosConceptos)
      ..where(
        (t) =>
            t.categoriaId.equals(categoriaId) & t.fechaEliminacion.isNotNull(),
      );

    return statement.write(
      PreciosConceptosCompanion(
        estatus: const Value(EstatusType.activo),
        fechaEliminacion: const Value(null),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );
  }

  /// Da de baja en una sola sentencia los conceptos vigentes de una categoría.
  Future<int> deactivatePreciosByCategoria(int categoriaId) {
    final now = DateTime.now();
    final statement = update(preciosConceptos)
      ..where(
        (t) => t.categoriaId.equals(categoriaId) & t.fechaEliminacion.isNull(),
      );

    return statement.write(
      PreciosConceptosCompanion(
        estatus: const Value(EstatusType.inactivo),
        fechaEliminacion: Value(now),
        fechaActualizacion: Value(now),
      ),
    );
  }

  /// Propaga los días de entrega de la categoría a todos sus conceptos.
  ///
  /// Recibe los días y no la fila de la categoría, para que quien acaba de
  /// actualizarla propague el valor nuevo sin volver a leerla.
  Future<int> changeDiasPreciosByCategoria({
    required int categoriaId,
    required int diasEntrega,
  }) {
    final statement = update(preciosConceptos)
      ..where((t) => t.categoriaId.equals(categoriaId));

    return statement.write(
      PreciosConceptosCompanion(
        diasEntrega: Value(diasEntrega),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );
  }

  /// Verifica que el concepto no exista ya. Expuesto para que la interfaz pueda
  /// avisar antes de pedir confirmación al usuario.
  Future<void> ensurePrecioUnico(PreciosConceptosCompanion row) {
    return _ensureUnico(
      categoriaId: row.categoriaId.value,
      clotheSize: row.clotheSize.value,
      nombreConcepto: row.nombreConcepto.value,
    );
  }

  JoinedSelectStatement _queryJoined() {
    return select(preciosConceptos).join([
      innerJoin(
        categoriaServicio,
        categoriaServicio.id.equalsExp(preciosConceptos.categoriaId),
      ),
    ]);
  }

  JoinedSelectStatement _queryFiltrado(FiltrosPrecios filtros) {
    final query = _queryJoined();

    // Los ids -1 y 0 representan "sin categoría seleccionada".
    if (filtros.categoriaId > 0) {
      query.where(preciosConceptos.categoriaId.equals(filtros.categoriaId));
    }

    final clotheSize = filtros.clotheSize;
    if (clotheSize != null) {
      query.where(preciosConceptos.clotheSize.equalsValue(clotheSize));
    }

    final estatus = filtros.estatus;
    if (estatus != null) {
      query.where(preciosConceptos.estatus.equalsValue(estatus));
    }

    if (filtros.nombre.isNotEmpty) {
      query.where(
        likeAny(filtros.nombre, [
          preciosConceptos.nombreConcepto,
          preciosConceptos.clotheSize,
          categoriaServicio.nombre,
        ]),
      );
    }

    query.orderBy(
      buildOrdering(
        ordenamiento: filtros.ordenamiento,
        columnas: _columnasOrdenables,
        ascendente: filtros.ascendente,
        desempate: preciosConceptos.id,
      ),
    );

    return query;
  }

  /// Un concepto queda identificado por categoría + tamaño + nombre.
  ///
  /// La búsqueda incluye las filas dadas de baja, porque siguen existiendo en
  /// la tabla: es la razón por la que `idx_precio_unico` no es un índice único
  /// y la unicidad se valida aquí.
  Future<void> _ensureUnico({
    required int categoriaId,
    required ClotheSizeType clotheSize,
    required String nombreConcepto,
    int? excluyendoId,
  }) async {
    final query = selectOnly(preciosConceptos)
      ..addColumns([preciosConceptos.id])
      ..where(
        preciosConceptos.categoriaId.equals(categoriaId) &
            preciosConceptos.clotheSize.equalsValue(clotheSize) &
            preciosConceptos.nombreConcepto.lower().equals(
              nombreConcepto.toLowerCase(),
            ),
      )
      ..limit(1);

    if (excluyendoId != null) {
      query.where(preciosConceptos.id.equals(excluyendoId).not());
    }

    if (await query.getSingleOrNull() == null) return;

    final categoria = await _nombreCategoria(categoriaId);
    throw SQLException(
      message:
          'Ya hay un registro en la base de datos con el concepto '
          '"$nombreConcepto" en la categoria "$categoria" y con el tamaño '
          '"${clotheSize.description}".',
    );
  }

  /// No se puede crear ni editar un concepto si su categoría está inactiva.
  Future<void> _ensureCategoriaActiva({
    required int categoriaId,
    required String nombreConcepto,
    required String accion,
  }) async {
    final categoria =
        await (select(categoriaServicio)
              ..where((t) => t.id.equals(categoriaId))
              ..limit(1))
            .getSingleOrNull();

    if (categoria == null) return;
    if (categoria.estatus != EstatusType.inactivo) return;

    throw SQLException(
      message:
          'No se puede $accion el concepto "$nombreConcepto" porque la '
          'categoria "${categoria.nombre}" está inactiva, porfavor active la '
          'categoria antes de continuar.',
    );
  }

  Future<String> _nombreCategoria(int categoriaId) async {
    final query = selectOnly(categoriaServicio)
      ..addColumns([categoriaServicio.nombre])
      ..where(categoriaServicio.id.equals(categoriaId))
      ..limit(1);

    final fila = await query.getSingleOrNull();
    return fila?.read(categoriaServicio.nombre) ?? '';
  }

  Future<PreciosConceptosEntry> _filaActual(int id) async {
    final fila =
        await (select(preciosConceptos)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .getSingleOrNull();

    if (fila != null) return fila;

    throw const SQLException(
      message: 'El concepto que se intentó actualizar ya no existe.',
    );
  }

  /// Escribe sobre la fila [id], descartando el id y la fecha de creación: son
  /// las dos columnas que una actualización nunca debe tocar.
  Future<void> _escribir(int id, PreciosConceptosCompanion row) async {
    final statement = update(preciosConceptos)..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
      ),
    );

    if (escritas > 0) return;

    throw const SQLException(
      message: 'El concepto que se intentó actualizar ya no existe.',
    );
  }

  List<PrecioConDetallesEntry> _toDetalles(List<TypedResult> rows) {
    return rows
        .map((row) => PrecioConDetallesEntry.fromRow(row, attachedDatabase))
        .toList();
  }
}
