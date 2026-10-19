import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/models/tables/clientes/cliente.dart';
import 'package:gestion_lavanderia/models/tables/shared/audit_columns.dart';
import 'package:gestion_lavanderia/models/tables/shared/enum_converters.dart';

/// Una orden no se da de baja lógicamente: su ciclo de vida se expresa con
/// `estatus` (`EstatusOrdenType`) y [fechaCierre], por eso no usa
/// `SoftDeleteColumn`.
///
/// El método de pago no vive aquí, sino en cada movimiento de `orden_history`.
@DataClassName('OrdenServicioEntry')
@TableIndex(name: 'idx_orden_folio', columns: {#folio})
@TableIndex(name: 'idx_orden_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_orden_estatus', columns: {#estatus})
@TableIndex(name: 'idx_orden_fecha_creacion', columns: {#fechaCreacion})
class OrdenServicio extends Table with TimestampColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Cliente, #id)();

  /// Formato `AAMM-NNNNN`, generado por `OrdenServicioDao.insertOrden`.
  TextColumn get folio => text()();
  TextColumn get descripcion => text().nullable()();

  /// "En curso", "Pagado", "Cerrada" o "Cancelada". El converter la entrega
  /// ya como `EstatusOrdenType`.
  TextColumn get estatus => text().map(const EstatusOrdenConverter())();
  RealColumn get total => real()();

  /// Saldo pendiente de la orden.
  RealColumn get restante => real()();
  DateTimeColumn get fechaCierre => dateTime().nullable()();
}
