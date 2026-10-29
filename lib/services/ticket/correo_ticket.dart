import 'dart:convert' show HtmlEscape;

import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';

/// Lo que dice el correo con el que se envía un ticket, y cómo se llama el
/// archivo.
///
/// Aparte del envío para poder leerlo y probarlo sin servidor: es texto que ve
/// el cliente, y un nombre mal escapado o un saldo equivocado se notan.
abstract final class CorreoTicket {
  static const _escapar = HtmlEscape();

  /// `Ticket 2610-0001.pdf`: el mismo nombre al descargar y al adjuntar.
  static String nombreArchivo(OrdenDetalleData orden) =>
      'Ticket ${orden.folio}.pdf';

  static String asunto(OrdenDetalleData orden, EmpresaData? empresa) {
    final de = _nombreEmpresa(empresa);

    return de.isEmpty
        ? 'Ticket de tu orden ${orden.folio}'
        : 'Ticket de tu orden ${orden.folio} · $de';
  }

  /// El cuerpo del correo: un saludo, en qué va la orden y el ticket adjunto.
  ///
  /// Corto a propósito: el detalle está en el PDF. Lo que se repite aquí es lo
  /// que el cliente quiere saber sin abrir nada —cuánto debe—.
  static String html(OrdenDetalleData orden, EmpresaData? empresa) {
    final nombre = _escapar.convert(orden.cliente.split(' ').first);
    final de = _escapar.convert(_nombreEmpresa(empresa));
    final saldo = orden.restante > 0.005
        ? 'Queda un saldo de <b>\$${orden.restante.toStringAsFixed(2)}</b> '
              'de un total de \$${orden.total.toStringAsFixed(2)}.'
        : 'Tu orden está <b>pagada</b>: '
              'total \$${orden.total.toStringAsFixed(2)}.';

    return '''
<p>Hola $nombre:</p>
<p>Te enviamos el ticket de tu orden <b>${orden.folio}</b>. $saldo</p>
<p>Lo encuentras adjunto en PDF.</p>
<p>¡Gracias por tu preferencia!${de.isEmpty ? '' : '<br>$de'}</p>
''';
  }

  static String _nombreEmpresa(EmpresaData? empresa) =>
      empresa?.nombre.trim() ?? '';
}
