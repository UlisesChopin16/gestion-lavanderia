import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/services/ticket/correo_ticket.dart';
import 'package:gestion_lavanderia/services/ticket/ticket_pdf.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// El ticket se genera con o sin empresa, con o sin logo, y el correo dice lo
/// que tiene que decir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  const sabana = PrecioData(
    categoriaId: 1,
    categoria: 'Ropa de cama',
    nombreConcepto: 'Sábana',
    importe: 50,
  );

  OrdenDetalleData orden({
    double restante = 30,
    String cliente = 'Lucía Pérez',
  }) {
    final fecha = DateTime(2026, 10, 28, 10);

    return OrdenDetalleData(
      id: 1,
      folio: '2610-0007',
      clienteId: 1,
      cliente: cliente,
      estatus: EstatusOrdenType.enCurso,
      total: 50,
      restante: restante,
      fechaCreacion: fecha,
      items: [
        ItemOrdenData(id: 1, precio: sabana, importe: 50, fechaEntrega: fecha),
      ],
      historial: [
        MovimientoData(
          id: 1,
          monto: 50 - restante,
          restante: restante,
          fecha: fecha,
        ),
      ],
    );
  }

  const empresa = EmpresaData(
    id: 1,
    nombre: 'Lavandería El Sol',
    telefono: '5551234567',
    direccion: DireccionData(
      id: 1,
      calle: 'Reforma',
      numeroExterior: '12',
      colonia: 'Centro',
      codigoPostal: 6000,
      ciudad: 'CDMX',
      estado: 'CDMX',
    ),
  );

  /// Un PDF empieza con su cabecera y termina con su marca de fin.
  void esUnPdf(List<int> bytes) {
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(
      latin1.decode(bytes.skip(bytes.length - 8).toList()),
      contains('%%EOF'),
    );
  }

  group('TicketPdf', () {
    test('genera un PDF con los datos de la empresa', () async {
      esUnPdf(
        await const TicketPdf().generar(orden: orden(), empresa: empresa),
      );
    });

    test('sin empresa configurada también sale', () async {
      esUnPdf(await const TicketPdf().generar(orden: orden()));
    });

    test('un logo que ya no está en disco no lo impide', () async {
      final conLogo = empresa.copyWith(logo: '/no/existe/logo.png');

      esUnPdf(
        await const TicketPdf().generar(orden: orden(), empresa: conLogo),
      );
    });
  });

  group('CorreoTicket', () {
    test('el archivo se llama como el folio', () {
      expect(CorreoTicket.nombreArchivo(orden()), 'Ticket 2610-0007.pdf');
    });

    test('el asunto dice de qué orden y de qué lavandería', () {
      expect(
        CorreoTicket.asunto(orden(), empresa),
        'Ticket de tu orden 2610-0007 · Lavandería El Sol',
      );
      expect(
        CorreoTicket.asunto(orden(), null),
        'Ticket de tu orden 2610-0007',
      );
    });

    test('el cuerpo dice cuánto debe, o que está pagada', () {
      expect(CorreoTicket.html(orden(), empresa), contains('\$30.00'));
      expect(
        CorreoTicket.html(orden(restante: 0), empresa),
        contains('<b>pagada</b>'),
      );
    });

    test('el nombre del cliente se escapa', () {
      final html = CorreoTicket.html(
        orden(cliente: '<b>Ana</b> López'),
        empresa,
      );

      expect(html, contains('&lt;b&gt;Ana&lt;'));
      expect(html, isNot(contains('<b>Ana')));
    });
  });
}
