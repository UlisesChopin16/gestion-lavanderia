import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';

/// Las reglas del reporte de ventas sin base ni archivo: qué días abarca
/// cada periodo, cuándo sale en Excel y qué suma.
void main() {
  // Un miércoles por la tarde: la hora no debe mover ningún periodo.
  final ahora = DateTime(2026, 11, 4, 18, 30);

  group('los periodos', () {
    RangoReporte rango(PeriodoReporte periodo) => periodo.rangoDesde(ahora)!;

    test('hoy es sólo hoy, sin importar la hora', () {
      final hoy = rango(PeriodoReporte.hoy);

      expect(hoy.desde, DateTime(2026, 11, 4));
      expect(hoy.hasta, DateTime(2026, 11, 4));
      // Hasta la medianoche que cierra el día: lo de esta tarde entra.
      expect(hoy.fin, DateTime(2026, 11, 5));
    });

    test('semana, mes y tres meses son los del selector de fechas', () {
      expect(rango(PeriodoReporte.semana).desde, DateTime(2026, 10, 28));
      expect(rango(PeriodoReporte.mes).desde, DateTime(2026, 10, 4));
      expect(rango(PeriodoReporte.tresMeses).desde, DateTime(2026, 8, 4));
      expect(rango(PeriodoReporte.anio).desde, DateTime(2025, 11, 4));
    });

    test('otras fechas no tiene rango hasta que se eligen', () {
      expect(PeriodoReporte.rango.rangoDesde(ahora), isNull);
    });

    test('hasta un mes sale en PDF; de ahí en adelante, en Excel', () {
      expect(rango(PeriodoReporte.hoy).formato, FormatoReporte.pdf);
      expect(rango(PeriodoReporte.semana).formato, FormatoReporte.pdf);
      expect(rango(PeriodoReporte.mes).formato, FormatoReporte.pdf);
      expect(rango(PeriodoReporte.tresMeses).formato, FormatoReporte.excel);
      expect(rango(PeriodoReporte.anio).formato, FormatoReporte.excel);
    });

    test('un rango elegido a mano corta en el mismo mes', () {
      final hasta = DateTime(2026, 11, 4);

      expect(
        RangoReporte(DateTime(2026, 10, 4), hasta).formato,
        FormatoReporte.pdf,
      );
      expect(
        RangoReporte(DateTime(2026, 10, 3), hasta).formato,
        FormatoReporte.excel,
      );
    });

    test('las fechas se aceptan en cualquier orden y con hora', () {
      final rango = RangoReporte(
        DateTime(2026, 11, 4, 23, 59),
        DateTime(2026, 11, 1, 8),
      );

      expect(rango.desde, DateTime(2026, 11, 1));
      expect(rango.hasta, DateTime(2026, 11, 4));
    });
  });

  group('cada orden', () {
    VentaReporte venta({
      double total = 100,
      double pagado = 0,
      bool cancelada = false,
    }) => VentaReporte(
      folio: '2611-0001',
      fecha: ahora,
      total: total,
      cancelada: cancelada,
      pagos: [
        if (pagado > 0)
          PagoReporte(
            folio: '2611-0001',
            fecha: ahora,
            metodo: MetodoPagoType.efectivo,
            monto: pagado,
          ),
      ],
    );

    test('dice cómo va su pago', () {
      expect(venta(pagado: 100).estado, EstadoPagoVenta.pagado);
      expect(venta(pagado: 40).estado, EstadoPagoVenta.parcial);
      expect(venta().estado, EstadoPagoVenta.pendiente);
      expect(
        venta(pagado: 40, cancelada: true).estado,
        EstadoPagoVenta.cancelado,
      );
    });

    test('el saldo es el total menos lo pagado', () {
      expect(venta(pagado: 40).saldo, 60);
      // Lo que quedó de restar doubles no es una deuda.
      expect(venta(pagado: 99.999).saldo, 0);
      expect(venta(pagado: 99.999).estado, EstadoPagoVenta.pagado);
    });

    test('una cancelada ya no debe nada', () {
      expect(venta(pagado: 40, cancelada: true).saldo, 0);
    });
  });

  group('el resumen', () {
    PagoReporte pago(
      String folio,
      int hora,
      MetodoPagoType metodo,
      double monto,
    ) => PagoReporte(
      folio: folio,
      fecha: DateTime(2026, 11, 4, hora),
      metodo: metodo,
      monto: monto,
    );

    final reporte = ReporteVentas(
      rango: RangoReporte(ahora, ahora),
      generado: ahora,
      ventas: [
        VentaReporte(
          folio: 'A',
          fecha: ahora,
          total: 300,
          pagos: [
            pago('A', 9, MetodoPagoType.efectivo, 100),
            pago('A', 17, MetodoPagoType.tarjeta, 200),
          ],
        ),
        VentaReporte(
          folio: 'B',
          fecha: ahora,
          total: 200,
          pagos: [pago('B', 12, MetodoPagoType.efectivo, 50)],
        ),
        VentaReporte(folio: 'C', fecha: ahora, total: 80),
        VentaReporte(
          folio: 'D',
          fecha: ahora,
          total: 1000,
          cancelada: true,
          pagos: [pago('D', 10, MetodoPagoType.transferencia, 500)],
        ),
      ],
    );

    test('las canceladas no cuentan en ningún total', () {
      expect(reporte.canceladas, 1);
      expect(reporte.totalVendido, 580);
      expect(reporte.cobrado, 350);
      expect(reporte.pendiente, 230);
    });

    test('lo cobrado y lo pendiente suman lo vendido', () {
      expect(reporte.cobrado + reporte.pendiente, reporte.totalVendido);
    });

    test('lo cobrado por método suma lo cobrado, y sólo los que hubo', () {
      expect(reporte.cobradoPorMetodo, {
        MetodoPagoType.efectivo: 150,
        MetodoPagoType.tarjeta: 200,
      });
      expect(
        reporte.cobradoPorMetodo.values.fold<double>(0, (a, b) => a + b),
        reporte.cobrado,
      );
    });

    test('el detalle de pagos va por folio, sin los de las canceladas', () {
      expect(
        [for (final pago in reporte.pagos) (pago.folio, pago.fecha.hour)],
        [('A', 9), ('A', 17), ('B', 12)],
      );
      expect(
        reporte.pagos.fold<double>(0, (suma, pago) => suma + pago.monto),
        reporte.cobrado,
      );
    });

    test('cada orden toma lo pagado y la fecha de pago de sus pagos', () {
      final venta = reporte.ventas.first;

      expect(venta.pagado, 300);
      expect(venta.fechaPago, DateTime(2026, 11, 4, 17));
      expect(reporte.ventas[2].fechaPago, isNull);
    });
  });

  group('el orden', () {
    VentaReporte venta(String folio) =>
        VentaReporte(folio: folio, fecha: ahora, total: 100);

    test('las órdenes van por folio, lleguen como lleguen', () {
      final reporte = ReporteVentas(
        rango: RangoReporte(ahora, ahora),
        generado: ahora,
        ventas: [venta('2611-0003'), venta('2610-0007'), venta('2611-0001')],
      );

      expect(reporte.ventas.map((v) => v.folio), [
        '2610-0007',
        '2611-0001',
        '2611-0003',
      ]);
    });

    test('el consecutivo se compara como número', () {
      // Un folio viejo de cinco dígitos va después de los de cuatro del
      // mismo mes, aunque como texto vaya antes.
      final folios = ['2610-00012', '2610-0002', '2609-0100']
        ..sort(compararFolios);

      expect(folios, ['2609-0100', '2610-0002', '2610-00012']);
    });
  });
}
