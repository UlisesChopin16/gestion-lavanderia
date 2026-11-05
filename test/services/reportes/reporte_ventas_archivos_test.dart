import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/models/data/reportes/reporte_ventas.dart';
import 'package:gestion_lavanderia/services/reportes/corte_caja_pdf.dart';
import 'package:gestion_lavanderia/services/reportes/libro_xlsx.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_excel.dart';
import 'package:gestion_lavanderia/services/reportes/reporte_ventas_pdf.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// Los archivos del reporte de ventas: que el Excel sea un libro bien armado
/// con los números como números, y que el PDF salga aunque sean muchas
/// páginas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  final dia = DateTime(2026, 10, 10, 9, 30);

  const empresa = EmpresaData(
    id: 1,
    nombre: 'El Sol',
    telefono: '5551234567',
    correo: 'hola@elsol.mx',
    direccion: DireccionData(
      id: 1,
      calle: 'Juárez',
      numeroExterior: '12',
      colonia: 'Centro',
      codigoPostal: 1000,
      ciudad: 'Toluca',
      estado: 'México',
    ),
  );

  ReporteVentas reporte({int ordenes = 2}) => ReporteVentas(
    rango: RangoReporte(DateTime(2026, 8, 4), DateTime(2026, 11, 4)),
    generado: DateTime(2026, 11, 4, 18),
    ventas: [
      for (var i = 0; i < ordenes; i++)
        VentaReporte(
          folio: '2610-${(i + 1).toString().padLeft(4, '0')}',
          fecha: dia,
          total: 250,
          pagos: [
            PagoReporte(
              folio: '2610-${(i + 1).toString().padLeft(4, '0')}',
              fecha: dia,
              metodo: i.isEven
                  ? MetodoPagoType.efectivo
                  : MetodoPagoType.tarjeta,
              monto: i.isEven ? 250 : 100,
            ),
          ],
        ),
    ],
  );

  /// El contenido de cada archivo del zip.
  Map<String, String> abrir(List<int> xlsx) => {
    for (final archivo in ZipDecoder().decodeBytes(xlsx))
      archivo.name: utf8.decode(archivo.content),
  };

  group('LibroXlsx', () {
    test('trae las partes que Excel necesita para abrirlo', () {
      final partes = abrir(
        const LibroXlsx().generar(
          const HojaXlsx(
            nombre: 'Ventas',
            filas: [
              [TextoXlsx('Hola')],
            ],
          ),
        ),
      );

      expect(
        partes.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/worksheets/sheet1.xml',
        ]),
      );
    });

    test('escapa el texto y quita lo que no es XML', () {
      final hoja = abrir(
        const LibroXlsx().generar(
          const HojaXlsx(
            nombre: 'Ventas',
            filas: [
              [TextoXlsx('Pérez & <Hijos>\t\x01')],
            ],
          ),
        ),
      )['xl/worksheets/sheet1.xml']!;

      expect(hoja, contains('Pérez &amp; &lt;Hijos&gt;'));
      expect(hoja, isNot(contains('\x01')));
    });

    test('las columnas pasan de la Z a la AA', () {
      expect(columnaXlsx(0), 'A');
      expect(columnaXlsx(25), 'Z');
      expect(columnaXlsx(26), 'AA');
      expect(columnaXlsx(27), 'AB');
    });

    test('las fechas van como Excel las cuenta', () {
      expect(serialExcel(DateTime(1900, 1, 1)), 2);
      expect(serialExcel(DateTime(2026, 11, 4, 12)), 46330.5);
    });

    test('cada estilo de celda está declarado en el libro', () {
      final estilos = abrir(
        const LibroXlsx().generar(const HojaXlsx(nombre: 'Ventas', filas: [])),
      )['xl/styles.xml']!;

      expect(
        estilos,
        contains('<cellXfs count="${EstiloXlsx.values.length}">'),
      );
    });
  });

  group('ReporteVentasExcel', () {
    test('una fila por orden, con importes y fechas como números', () {
      final hoja = abrir(
        const ReporteVentasExcel().generar(reporte(), empresa: empresa),
      )['xl/worksheets/sheet1.xml']!;

      expect(hoja, contains('2610-0001'));
      expect(hoja, contains('2610-0002'));
      // Los datos de la lavandería, arriba.
      expect(hoja, contains('El Sol'));
      expect(
        hoja,
        contains('Juárez, No. 12, Centro, Toluca, México, C.P. 01000'),
      );
      expect(hoja, contains('Tel. 5551234567  ·  hola@elsol.mx'));
      expect(hoja, contains('<v>250.0</v>'));
      expect(hoja, contains('<v>${serialExcel(dia)}</v>'));
      for (final columna in ReporteVentas.columnas) {
        expect(hoja, contains('>$columna<'));
      }
    });

    test('el filtro cubre el encabezado y las órdenes', () {
      final hoja = abrir(
        const ReporteVentasExcel().generar(reporte(ordenes: 3)),
      )['xl/worksheets/sheet1.xml']!;

      // Sin empresa: título, periodo, generado y un renglón en blanco; el
      // encabezado es la fila 5 y las tres órdenes, de la 6 a la 8.
      expect(hoja, contains('<autoFilter ref="A5:F8"/>'));
      expect(hoja, contains('<pane ySplit="5"'));
    });

    test('después va lo cobrado, por método y contra lo pendiente', () {
      final hoja = abrir(
        const ReporteVentasExcel().generar(reporte()),
      )['xl/worksheets/sheet1.xml']!;

      expect(hoja, contains('Total cobrado'));
      expect(hoja, contains('Cobrado por método de pago'));
      expect(hoja, contains('>Efectivo<'));
      expect(hoja, contains('>Tarjeta<'));
      expect(hoja, contains('Cobrado vs. pendiente'));
      // Lo cobrado de las dos órdenes: 250 y 100.
      expect(hoja, contains('<v>350.0</v>'));
    });

    test('al final, el detalle con un renglón por pago', () {
      final hoja = abrir(
        const ReporteVentasExcel().generar(reporte(ordenes: 3)),
      )['xl/worksheets/sheet1.xml']!;
      final detalle = hoja.substring(hoja.indexOf('Detalle de pagos'));

      for (final columna in ReporteVentas.columnasPagos) {
        expect(detalle, contains('>$columna<'));
      }
      // Los tres pagos: dos de 250 y uno de 100, cada uno con su fecha y
      // hora, y al final su total.
      expect(
        RegExp('<v>${serialExcel(dia)}</v>').allMatches(detalle).length,
        3,
      );
      expect(detalle, contains('<v>600.0</v>'));
    });

    test('sin órdenes no lleva filtro', () {
      final hoja = abrir(
        const ReporteVentasExcel().generar(reporte(ordenes: 0)),
      )['xl/worksheets/sheet1.xml']!;

      expect(hoja, isNot(contains('<autoFilter')));
      expect(hoja, contains('Sin cobros en el periodo'));
      expect(hoja, contains('Sin pagos en el periodo'));
    });
  });

  group('ReporteVentasPdf', () {
    void esUnPdf(List<int> bytes) {
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    }

    test('sale con órdenes y sin ellas', () async {
      esUnPdf(await const ReporteVentasPdf().generar(reporte()));
      esUnPdf(await const ReporteVentasPdf().generar(reporte(ordenes: 0)));
    });

    test('una tabla larga se parte en varias páginas', () async {
      final pdf = await const ReporteVentasPdf().generar(
        reporte(ordenes: 150),
        empresa: empresa,
      );

      esUnPdf(pdf);
      // Cada página es un objeto `/Type /Page` del documento.
      final paginas = RegExp(r'/Type\s*/Page\b')
          .allMatches(latin1.decode(pdf))
          .length;
      expect(paginas, greaterThan(1));
    });
  });

  group('CorteCajaPdf', () {
    test('sale con cobros y sin ellos', () async {
      final corte = CorteCaja(
        dia: DateTime(2026, 11, 4),
        generado: DateTime(2026, 11, 4, 21),
        cobros: [
          CobroCorte(
            folio: '2611-0001',
            cliente: 'Ana López',
            fecha: DateTime(2026, 11, 4, 9),
            metodo: MetodoPagoType.efectivo,
            monto: 150,
            recibido: 500,
          ),
          CobroCorte(
            folio: '2611-0002',
            cliente: 'Luis Pérez',
            fecha: DateTime(2026, 11, 4, 10),
            metodo: MetodoPagoType.tarjeta,
            monto: 200,
          ),
        ],
      );
      final vacio = CorteCaja(
        dia: DateTime(2026, 11, 4),
        generado: DateTime(2026, 11, 4, 21),
        cobros: const [],
      );

      for (final pdf in [
        await const CorteCajaPdf().generar(corte, empresa: empresa),
        await const CorteCajaPdf().generar(vacio),
      ]) {
        expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
      }
    });
  });
}
