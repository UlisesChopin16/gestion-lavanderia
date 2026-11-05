import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';

/// Lo que el reporte de ventas lee de la base: las órdenes recibidas en el
/// periodo, con todo lo que se les ha cobrado y cómo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ReportesLocalDatasource reportes;
  late int clienteId;

  /// Una orden recibida el [dia], con sus cobros: `(fecha, monto, método)`.
  /// El primer movimiento es el del alta, aunque no traiga dinero.
  Future<String> orden({
    required DateTime dia,
    required double total,
    List<(DateTime, double, MetodoPagoType)> cobros = const [],
    EstatusOrdenType estatus = EstatusOrdenType.enCurso,
  }) async {
    final pagado = cobros.fold<double>(0, (suma, cobro) => suma + cobro.$2);
    final creada = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: estatus,
        total: total,
        restante: total - pagado,
        fechaCreacion: dia,
      ),
    );
    // La inserción fecha la orden con la hora actual: se le pone la suya.
    await (db.update(db.ordenServicio)..where((t) => t.id.equals(creada.id)))
        .write(OrdenServicioCompanion(fechaCreacion: Value(dia)));

    await db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: creada.id,
        monto: 0,
        restante: total,
        metodoPago: MetodoPagoType.efectivo,
        fecha: dia,
      ),
    );
    for (final (fecha, monto, metodo) in cobros) {
      await db.ordenHistoryDao.insertHistory(
        OrdenHistoryCompanion.insert(
          ordenId: creada.id,
          monto: monto,
          restante: 0,
          metodoPago: metodo,
          fecha: fecha,
        ),
      );
    }

    return creada.folio;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reportes = ReportesLocalDatasource(db.ordenServicioDao, db.ordenHistoryDao);

    clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );
  });

  tearDown(() => db.close());

  final octubre = RangoReporte(DateTime(2026, 10), DateTime(2026, 10, 31));

  test('sólo entran las órdenes recibidas en el periodo', () async {
    await orden(dia: DateTime(2026, 9, 30, 23, 59), total: 10);
    final primera = await orden(dia: DateTime(2026, 10, 1), total: 20);
    // El último día entra completo, hasta la noche.
    final ultima = await orden(dia: DateTime(2026, 10, 31, 22), total: 30);
    await orden(dia: DateTime(2026, 11, 1), total: 40);

    final reporte = await reportes.ventas(octubre);

    expect(reporte.ventas.map((v) => v.folio), [primera, ultima]);
  });

  test('cada orden trae sus pagos y su último pago', () async {
    final dia = DateTime(2026, 10, 10, 9);

    await orden(
      dia: dia,
      total: 300,
      cobros: [
        (DateTime(2026, 10, 10, 9), 100, MetodoPagoType.efectivo),
        // Un pago que llegó después del periodo sigue siendo de esta orden.
        (DateTime(2026, 11, 3, 17), 200, MetodoPagoType.tarjeta),
      ],
    );

    final venta = (await reportes.ventas(octubre)).ventas.single;

    expect(venta.total, 300);
    expect(venta.pagado, 300);
    expect(venta.estado, EstadoPagoVenta.pagado);
    expect(venta.fechaPago, DateTime(2026, 11, 3, 17));
    expect(
      [for (final pago in venta.pagos) (pago.folio, pago.metodo, pago.monto)],
      [
        (venta.folio, MetodoPagoType.efectivo, 100),
        (venta.folio, MetodoPagoType.tarjeta, 200),
      ],
    );
  });

  test('sin cobros no hay fecha de pago', () async {
    await orden(dia: DateTime(2026, 10, 10), total: 80);

    final venta = (await reportes.ventas(octubre)).ventas.single;

    expect(venta.estado, EstadoPagoVenta.pendiente);
    expect(venta.fechaPago, isNull);
    expect(venta.pagos, isEmpty);
  });

  test('una cancelada sale como cancelada', () async {
    await orden(
      dia: DateTime(2026, 10, 10),
      total: 80,
      estatus: EstatusOrdenType.cancelada,
    );

    final reporte = await reportes.ventas(octubre);

    expect(reporte.ventas.single.estado, EstadoPagoVenta.cancelado);
    expect(reporte.totalVendido, 0);
  });
}
