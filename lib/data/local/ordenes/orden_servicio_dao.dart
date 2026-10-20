import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/models/tables/ordenes/orden_servicio.dart';

part 'orden_servicio_dao.g.dart';

@DriftAccessor(tables: [OrdenServicio])
class OrdenServicioDao extends DatabaseAccessor<AppDatabase>
    with _$OrdenServicioDaoMixin {
  OrdenServicioDao(super.db);

  Future<OrdenServicioEntry?> getById(int id) {
    final query = select(ordenServicio)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Inserta la orden asignándole folio.
  ///
  /// El folio se calcula dentro de la misma transacción que la inserción: si se
  /// calculara antes, dos órdenes creadas al mismo tiempo podían recibir el
  /// mismo folio.
  Future<OrdenServicioEntry> insertOrden(OrdenServicioCompanion row) {
    return transaction(() async {
      final now = DateTime.now();
      final data = row.copyWith(
        folio: Value(await _generarFolio(now)),
        fechaCreacion: Value(now),
        fechaActualizacion: Value(now),
      );

      final id = await into(ordenServicio).insert(data);
      final entry = await getById(id);

      if (entry == null) {
        throw const SQLException(
          message: 'Error al insertar la orden de servicio',
        );
      }

      return entry;
    });
  }

  /// Escribe sobre la orden [id] las columnas que traiga [row] y devuelve la
  /// fila tal como quedó.
  ///
  /// `fechaActualizacion` siempre viene informada, que es lo que la capa
  /// superior necesita para fechar el movimiento del historial. La fila se
  /// vuelve a leer en lugar de construirse aquí, porque el companion puede
  /// traer sólo una parte de las columnas.
  Future<OrdenServicioEntry> updateOrden({
    required int id,
    required OrdenServicioCompanion row,
  }) async {
    final statement = update(ordenServicio)..where((t) => t.id.equals(id));

    final escritas = await statement.write(
      row.copyWith(
        id: const Value.absent(),
        fechaCreacion: const Value.absent(),
        fechaActualizacion: Value(DateTime.now()),
      ),
    );

    final entry = escritas > 0 ? await getById(id) : null;

    if (entry == null) {
      throw const SQLException(
        message: 'Error al actualizar la orden de servicio',
      );
    }

    return entry;
  }

  /// Folio con formato `AAMM-NNNN`, consecutivo dentro del mes.
  ///
  /// Los dos últimos dígitos del año, el mes y cuatro de consecutivo:
  /// `2610-0001` es la primera orden de octubre de 2026. Se dicta por
  /// teléfono y se copia a mano en el ticket, así que es lo más corto que
  /// sigue diciendo de cuándo es la orden.
  ///
  /// El consecutivo se obtiene del folio más alto del mes y no de la fecha de
  /// creación: así el número siempre corresponde al prefijo que lo acompaña,
  /// incluso para una orden creada justo al cambiar de mes. Como el consecutivo
  /// va rellenado a cuatro dígitos, el máximo alfabético coincide con el
  /// numérico (válido hasta 9 999 órdenes en un mismo mes).
  Future<String> _generarFolio(DateTime fecha) async {
    final anio = (fecha.year % 100).toString().padLeft(2, '0');
    final prefijo = '$anio${fecha.month.toString().padLeft(2, '0')}-';

    final maximo = ordenServicio.folio.max();
    final query = selectOnly(ordenServicio)
      ..addColumns([maximo])
      ..where(ordenServicio.folio.like('$prefijo%'));

    final ultimoFolio = (await query.getSingleOrNull())?.read(maximo);
    final consecutivo =
        (int.tryParse(ultimoFolio?.split('-').last ?? '') ?? 0) + 1;

    return '$prefijo${consecutivo.toString().padLeft(4, '0')}';
  }
}
