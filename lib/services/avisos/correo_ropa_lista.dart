import 'dart:convert' show HtmlEscape;

import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';

/// Lo que dice el correo que le avisa al cliente que su ropa está lista.
///
/// Aparte del envío para poder leerlo y probarlo sin servidor: es texto que
/// ve el cliente.
///
/// Los estilos van en cada etiqueta y la forma en tablas, no en una hoja de
/// estilos: es lo único que respetan igual Gmail, Outlook y los teléfonos.
abstract final class CorreoRopaLista {
  static const _escapar = HtmlEscape();

  static String asunto(OrdenDetalleData orden, EmpresaData? empresa) {
    final de = empresa?.nombre.trim() ?? '';

    return de.isEmpty
        ? 'Tu ropa de la orden ${orden.folio} está lista'
        : 'Tu ropa de la orden ${orden.folio} está lista · $de';
  }

  /// La ropa que se anuncia: toda la que ya está lista y no se ha llevado,
  /// no sólo la que se marcó ahora. Al cliente le importa qué puede recoger.
  static List<ItemOrdenData> listos(OrdenDetalleData orden) =>
      orden.items.where((item) => item.esperaAlCliente).toList();

  static String html(OrdenDetalleData orden, EmpresaData? empresa) {
    final nombre = _escapar.convert(orden.cliente.split(' ').first);
    final de = _escapar.convert(empresa?.nombre.trim() ?? '');
    final listos = CorreoRopaLista.listos(orden);
    final enProceso = orden.items
        .where((item) => item.estaPendiente && !item.estaListo)
        .length;
    final (fondo, tinta) = _colores(empresa);

    final renglones = StringBuffer();
    for (final (indice, item) in listos.indexed) {
      final rayado = indice.isOdd ? 'background:#f6f8fa;' : '';
      renglones.write(
        '<tr>'
        '<td style="padding:10px 12px;$rayado">'
        '${_escapar.convert(item.concepto)}'
        '<div style="font-size:12px;color:#57606a;">'
        '${_escapar.convert(_debajo(item))}</div></td>'
        '<td align="right" style="padding:10px 12px;white-space:nowrap;'
        '$rayado">${_cantidad(item)}</td>'
        '</tr>',
      );
    }

    final saldo = orden.restante > 0.005
        ? 'Al recogerla, queda un saldo de <b>${orden.restante.enPesos}</b> '
              'de un total de ${orden.total.enPesos}.'
        : 'Tu orden ya está <b>pagada</b>: sólo pasa por ella.';

    final faltan = switch (enProceso) {
      0 => '',
      1 =>
        '<p style="margin:16px 0 0;color:#57606a;">Todavía estamos '
            'trabajando en 1 concepto más. Te avisaremos cuando esté '
            'listo.</p>',
      _ =>
        '<p style="margin:16px 0 0;color:#57606a;">Todavía estamos '
            'trabajando en $enProceso conceptos más. Te avisaremos cuando '
            'estén listos.</p>',
    };

    final direccion = _escapar.convert(empresa?.direccionImpresa ?? '');
    final telefono = _escapar.convert(empresa?.telefono.trim() ?? '');
    final dondeEstamos = [
      if (direccion.isNotEmpty) direccion,
      if (telefono.isNotEmpty) 'Tel. $telefono',
    ];

    return '''
<div style="background:#f3f4f6;padding:24px 12px;font-family:'Segoe UI',Arial,sans-serif;color:#1f2328;font-size:15px;line-height:1.5;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:12px;border-collapse:separate;overflow:hidden;">
<tr><td style="background:$fondo;color:$tinta;padding:20px 24px;">
${de.isEmpty ? '' : '<div style="font-size:13px;opacity:0.85;">$de</div>'}
<div style="font-size:22px;font-weight:600;margin-top:2px;">¡Tu ropa está lista!</div>
</td></tr>
<tr><td style="padding:24px;">
<p style="margin:0 0 12px;">Hola $nombre:</p>
<p style="margin:0 0 16px;">Ya terminamos tu ropa de la orden <b>${orden.folio}</b>. Puedes pasar por ella cuando gustes.</p>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;border:1px solid #d0d7de;border-radius:8px;">
<tr><th align="left" style="padding:10px 12px;background:#eef1f4;font-size:13px;color:#57606a;font-weight:600;">Lo que está listo</th><th align="right" style="padding:10px 12px;background:#eef1f4;font-size:13px;color:#57606a;font-weight:600;">Cantidad</th></tr>
$renglones
</table>
$faltan
<p style="margin:16px 0 0;padding:12px 14px;background:#f6f8fa;border-radius:8px;">$saldo</p>
${dondeEstamos.isEmpty ? '' : '<p style="margin:16px 0 0;">Te esperamos en:<br>${dondeEstamos.join('<br>')}</p>'}
<p style="margin:16px 0 0;">¡Gracias por tu preferencia!${de.isEmpty ? '' : '<br><b>$de</b>'}</p>
</td></tr>
</table>
</div>
''';
  }

  /// Lo que va debajo del nombre: la categoría y, si se anotó, lo que
  /// distingue a la prenda —"Lavandería · blanca, manga larga"—, para que el
  /// cliente sepa cuál de sus playeras ya está.
  static String _debajo(ItemOrdenData item) => item.detalle.isEmpty
      ? item.precio.categoria
      : '${item.precio.categoria} · ${item.detalle}';

  /// `2 Piezas`, `3.5 Kgs`.
  static String _cantidad(ItemOrdenData item) {
    final cantidad = item.cantidad;
    final numero = cantidad == cantidad.roundToDouble()
        ? cantidad.toStringAsFixed(0)
        : cantidad.toStringAsFixed(1);
    final unidad = cantidad == 1
        ? item.precio.tipoUnidad.value
        : item.precio.tipoUnidad.plural;

    return '$numero $unidad';
  }

  /// La franja de arriba en el color de la empresa, con letra blanca o
  /// negra según lo que se lea sobre él: un color claro con letra blanca no
  /// se lee.
  static (String fondo, String tinta) _colores(EmpresaData? empresa) {
    final color = empresa?.color;
    if (color == null) return ('#1f4e78', '#ffffff');

    final hex = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final tinta = color.computeLuminance() > 0.45 ? '#1f2328' : '#ffffff';

    return ('#$hex', tinta);
  }
}
