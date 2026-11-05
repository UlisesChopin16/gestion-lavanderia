import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';

/// Lo que los reportes leen de la base: las órdenes recibidas en el periodo
/// con lo que se les ha cobrado, los cobros de cada día, lo que se debe y la
/// ropa que falta por entregar.
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
    reportes = ReportesLocalDatasource(
      db.ordenServicioDao,
      db.ordenHistoryDao,
      db.itemServicioOrdenDao,
    );

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

  group('el corte de caja', () {
    final hoy = DateTime(2026, 11, 4);

    test('va por el día del cobro, no por el de la orden', () async {
      // Una orden de octubre que se terminó de pagar hoy: el abono de hoy
      // está en el corte de hoy.
      final vieja = await orden(
        dia: DateTime(2026, 10, 20, 9),
        total: 300,
        cobros: [
          (DateTime(2026, 10, 20, 9), 100, MetodoPagoType.efectivo),
          (DateTime(2026, 11, 4, 17), 200, MetodoPagoType.tarjeta),
        ],
      );
      // El último instante del día entra; la medianoche siguiente, no.
      final nueva = await orden(
        dia: DateTime(2026, 11, 4, 23, 59),
        total: 50,
        cobros: [(DateTime(2026, 11, 4, 23, 59), 50, MetodoPagoType.efectivo)],
      );
      await orden(
        dia: DateTime(2026, 11, 5),
        total: 70,
        cobros: [(DateTime(2026, 11, 5), 70, MetodoPagoType.efectivo)],
      );

      final corte = (await reportes.estadisticasCorte(hoy)).corte;

      expect(
        [for (final c in corte.cobros) (c.folio, c.monto, c.metodo)],
        [
          (vieja, 200, MetodoPagoType.tarjeta),
          (nueva, 50, MetodoPagoType.efectivo),
        ]..sort((a, b) => a.$1.compareTo(b.$1)),
      );
      expect(corte.cobros.first.cliente, 'Ana López');
      expect(corte.dia, hoy);
    });

    test('el alta sin abono no es un cobro', () async {
      // `orden` deja siempre el movimiento del alta, en cero.
      await orden(dia: DateTime(2026, 11, 4, 10), total: 80);

      expect((await reportes.estadisticasCorte(hoy)).corte.cobros, isEmpty);
    });

    test('trae con cuánto pagó el cliente', () async {
      final creada = await db.ordenServicioDao.insertOrden(
        OrdenServicioCompanion.insert(
          clienteId: clienteId,
          folio: '',
          estatus: EstatusOrdenType.pagado,
          total: 150,
          restante: 0,
          fechaCreacion: DateTime(2026, 11, 4, 9),
        ),
      );
      await db.ordenHistoryDao.insertHistory(
        OrdenHistoryCompanion.insert(
          ordenId: creada.id,
          monto: 150,
          restante: 0,
          metodoPago: MetodoPagoType.efectivo,
          recibido: const Value(500),
          fecha: DateTime(2026, 11, 4, 9),
        ),
      );

      final cobro = (await reportes.estadisticasCorte(hoy)).corte.cobros.single;

      expect(cobro.recibido, 500);
      expect(cobro.cambio, 350);
    });

    test(
      'trae lo cobrado en los siete días que terminan en el del corte',
      () async {
        await orden(
          dia: DateTime(2026, 10, 29, 10),
          total: 40,
          cobros: [(DateTime(2026, 10, 29, 10), 40, MetodoPagoType.efectivo)],
        );
        await orden(
          dia: DateTime(2026, 11, 3, 10),
          total: 100,
          cobros: [
            (DateTime(2026, 11, 3, 10), 60, MetodoPagoType.efectivo),
            (DateTime(2026, 11, 4, 12), 40, MetodoPagoType.tarjeta),
          ],
        );
        // Un día antes de la semana: no entra.
        await orden(
          dia: DateTime(2026, 10, 28, 10),
          total: 999,
          cobros: [(DateTime(2026, 10, 28, 10), 999, MetodoPagoType.efectivo)],
        );

        final estadisticas = await reportes.estadisticasCorte(hoy);

        expect(estadisticas.semana.map((d) => d.dia), [
          for (var dia = 29; dia <= 35; dia++) DateTime(2026, 10, dia),
        ]);
        expect(estadisticas.semana.map((d) => d.total), [
          40,
          0,
          0,
          0,
          0,
          60,
          40,
        ]);
        // El corte es sólo del último día.
        expect(estadisticas.corte.total, 40);
      },
    );
  });

  group('las cuentas por cobrar', () {
    test(
      'son las órdenes con saldo, sin las pagadas ni las canceladas',
      () async {
        final debe = await orden(
          dia: DateTime(2026, 10, 1),
          total: 300,
          cobros: [(DateTime(2026, 10, 1), 100, MetodoPagoType.efectivo)],
        );
        await orden(
          dia: DateTime(2026, 10, 2),
          total: 50,
          cobros: [(DateTime(2026, 10, 2), 50, MetodoPagoType.efectivo)],
        );
        await orden(
          dia: DateTime(2026, 10, 3),
          total: 80,
          estatus: EstatusOrdenType.cancelada,
        );

        final cuentas = await reportes.cuentasPorCobrar(
          ahora: DateTime(2026, 11, 5, 9),
        );

        final saldo = cuentas.saldos.single;
        expect(saldo.folio, debe);
        expect(saldo.saldo, 200);
        expect(saldo.cliente, 'Ana López');
        expect(saldo.telefono, '5551234567');
        expect(saldo.antiguedadAl(cuentas.hoy), AntiguedadSaldo.masDeUnMes);
      },
    );
  });

  group('la ropa pendiente', () {
    late int precioId;

    setUp(() async {
      final categoriaId = await db.categoriaServicioDao.insertCategoria(
        CategoriaServicioCompanion.insert(
          nombre: 'Planchado',
          estatus: EstatusType.activo,
          diasEntrega: 2,
          fechaCreacion: DateTime.now(),
        ),
      );
      precioId = await db.preciosConceptosDao.insertPrecio(
        PreciosConceptosCompanion.insert(
          categoriaId: categoriaId,
          clotheSize: ClotheSizeType.king,
          nombreConcepto: 'Camisa',
          diasEntrega: 2,
          tipoUnidad: UnitType.pieza,
          importe: 25,
          estatus: EstatusType.activo,
          fechaCreacion: DateTime.now(),
        ),
      );
    });

    /// Agrega a la orden [folio] un renglón prometido para [entrega].
    Future<void> item(
      String folio,
      DateTime entrega, {
      double cantidad = 1,
      bool entregado = false,
    }) async {
      final ordenId = (await (db.select(
        db.ordenServicio,
      )..where((t) => t.folio.equals(folio))).getSingle()).id;
      await db.itemServicioOrdenDao.insertItem(
        ItemServicioOrdenCompanion.insert(
          ordenId: ordenId,
          precioConceptoId: precioId,
          cantidad: cantidad,
          importe: 25 * cantidad,
          estaEntregado: Value(entregado),
          fechaEntrega: entrega,
          fechaCreacion: DateTime.now(),
        ),
      );
    }

    test(
      'junta por orden lo que falta, sin lo entregado ni lo cancelado',
      () async {
        final pendiente = await orden(dia: DateTime(2026, 11, 1), total: 75);
        await item(pendiente, DateTime(2026, 11, 3), cantidad: 2);
        await item(pendiente, DateTime(2026, 11, 7));
        await item(pendiente, DateTime(2026, 11, 2), entregado: true);

        final entregada = await orden(dia: DateTime(2026, 11, 1), total: 25);
        await item(entregada, DateTime(2026, 11, 3), entregado: true);

        final cancelada = await orden(
          dia: DateTime(2026, 11, 1),
          total: 25,
          estatus: EstatusOrdenType.cancelada,
        );
        await item(cancelada, DateTime(2026, 11, 3));

        final ropa = await reportes.ropaPendiente(
          ahora: DateTime(2026, 11, 5, 9),
        );

        final conRopa = ropa.ordenes.single;
        expect(conRopa.folio, pendiente);
        expect(conRopa.conceptos.map((c) => c.descripcion), [
          '2 Piezas Camisa',
          '1 Pieza Camisa',
        ]);
        expect(conRopa.saldo, 75);
        expect(conRopa.estadoAl(ropa.hoy), EstadoEntrega.vencida);
        expect(conRopa.diasDeRetraso(ropa.hoy), 2);
      },
    );
  });
}
