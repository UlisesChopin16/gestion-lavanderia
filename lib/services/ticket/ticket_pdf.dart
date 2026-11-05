import 'dart:typed_data';

import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/services/fuentes_pdf.dart';
import 'package:gestion_lavanderia/services/logo_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// El ticket de una orden como PDF, en rollo de 80 mm.
///
/// Es el mismo archivo para todo: la vista previa son imágenes de este PDF, y
/// es este PDF el que se descarga y el que se adjunta al correo. Así lo que se
/// ve en pantalla no puede diferir de lo que recibe el cliente.
///
/// El rollo de 80 mm es el ancho de las impresoras térmicas de mostrador. El
/// largo no es fijo: el papel mide lo que mida la orden.
///
/// Lleva, de arriba abajo, lo que un cliente busca en un ticket: de dónde es,
/// qué orden es y para quién, qué dejó y para cuándo, cuánto lleva pagado y
/// cuánto le falta, y cómo pagó.
class TicketPdf {
  const TicketPdf();

  Future<Uint8List> generar({
    required OrdenDetalleData orden,
    EmpresaData? empresa,
  }) async {
    final documento = pw.Document(
      title: 'Ticket ${orden.folio}',
      author: empresa?.nombre,
      theme: await FuentesPdf.tema(),
    );
    final logo = await LogoPdf.de(empresa);
    final nota = orden.descripcion?.trim() ?? '';

    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.DefaultTextStyle(
          style: const pw.TextStyle(fontSize: 8, color: _Tinta.texto),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _Empresa(empresa: empresa, logo: logo),
              _Separador(),
              _DatosOrden(orden: orden),
              _Separador(),
              _Conceptos(items: orden.items),
              _Separador(),
              _Cuentas(orden: orden),
              if (orden.historial.any((m) => m.huboAbono)) ...[
                _Separador(),
                _Pagos(historial: orden.historial),
              ],
              if (nota.isNotEmpty) ...[_Separador(), _Nota(nota: nota)],
              _Separador(),
              _Despedida(orden: orden),
            ],
          ),
        ),
      ),
    );

    return documento.save();
  }

  /// `Pagó con $500.00  ·  Cambio $330.00`: el renglón que va bajo un pago
  /// en efectivo. En `null` cuando no se sabe con cuánto pagó: con otro
  /// método, o en los pagos de antes de que se guardara.
  static String? efectivoRecibido(MovimientoData movimiento) {
    final recibido = movimiento.recibido;
    final cambio = movimiento.cambio;
    if (recibido == null || cambio == null) return null;

    final vuelto = cambio > 0.005 ? 'Cambio ${cambio.enPesos}' : 'Sin cambio';

    return 'Pagó con ${recibido.enPesos}  ·  $vuelto';
  }
}

// Las secciones son widgets del paquete `pdf` —`pw.StatelessWidget`—, no de
// Flutter: se parecen en la forma, pero se dibujan una vez, en el documento.

/// De dónde es el ticket: logo, nombre, dirección y cómo contactar.
class _Empresa extends pw.StatelessWidget {
  _Empresa({required this.empresa, required this.logo});

  final EmpresaData? empresa;
  final pw.MemoryImage? logo;

  /// El logo no pasa de este alto: en un rollo, un logo cuadrado grande
  /// empujaba la orden fuera de la vista.
  static const double _altoLogo = 56;

  @override
  pw.Widget build(pw.Context context) {
    final empresa = this.empresa;
    final logo = this.logo;
    final contacto = empresa?.contacto ?? const <String>[];
    final direccion = empresa?.direccionImpresa ?? '';

    return pw.Column(
      children: [
        if (logo != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Image(logo, height: _altoLogo, fit: pw.BoxFit.contain),
          ),
        if (empresa != null && empresa.nombre.isNotEmpty)
          pw.Text(
            empresa.nombre,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        if (direccion.isNotEmpty) _Pequeno(direccion, arriba: 2),
        if (contacto.isNotEmpty) _Pequeno(contacto.join('  ·  '), arriba: 2),
      ],
    );
  }
}

/// Qué orden es, cuándo se recibió y de quién es.
class _DatosOrden extends pw.StatelessWidget {
  _DatosOrden({required this.orden});

  final OrdenDetalleData orden;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _Etiqueta('ORDEN'),
            pw.Text(
              orden.folio,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        _Renglon('Recibida', orden.fechaCreacion.formatFullDate),
        _Renglon('Cliente', orden.cliente),
        if (orden.clienteTelefono.isNotEmpty)
          _Renglon('Teléfono', orden.clienteTelefono),
      ],
    );
  }
}

/// La ropa que dejó el cliente, renglón por renglón.
class _Conceptos extends pw.StatelessWidget {
  _Conceptos({required this.items});

  final List<ItemOrdenData> items;

  @override
  pw.Widget build(pw.Context context) {
    final cuantos = items.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _Etiqueta(cuantos == 1 ? '1 CONCEPTO' : '$cuantos CONCEPTOS'),
        pw.SizedBox(height: 4),
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: _Concepto(item: item),
          ),
      ],
    );
  }
}

/// Una prenda: qué es y lo que cuesta; debajo, cuánto, a cómo y para cuándo.
class _Concepto extends pw.StatelessWidget {
  _Concepto({required this.item});

  final ItemOrdenData item;

  @override
  pw.Widget build(pw.Context context) {
    final precio = item.precio;
    final unidad = item.cantidad == 1
        ? precio.tipoUnidad.value
        : precio.tipoUnidad.plural;
    final entrega = item.estaEntregado
        ? 'Entregado el ${item.fechaEntregado.formatDate}'
        : 'Entrega: ${item.fechaEntrega.formatDate}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                precio.descripcion,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(item.importe.enPesos),
          ],
        ),
        _Pequeno(
          '${_cantidad(item.cantidad)} $unidad × ${precio.importe.enPesos}'
          '  ·  $entrega',
          centrado: false,
        ),
      ],
    );
  }
}

/// Lo que cuesta, lo que se ha pagado y lo que falta. Lo que falta va más
/// grande y sobre fondo: es la cifra por la que el cliente mira el ticket.
class _Cuentas extends pw.StatelessWidget {
  _Cuentas({required this.orden});

  final OrdenDetalleData orden;

  @override
  pw.Widget build(pw.Context context) {
    final debe = orden.restante > 0.005;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _Renglon('Total', orden.total.enPesos),
        _Renglon('Pagado', orden.pagado.enPesos),
        pw.SizedBox(height: 3),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: _Tinta.resalte,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                debe ? 'RESTA' : 'PAGADA',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                (debe ? orden.restante : 0.0).enPesos,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Los cobros, del primero al último. Bajo los que fueron en efectivo, con
/// cuánto pagó el cliente y cuánto se le devolvió.
class _Pagos extends pw.StatelessWidget {
  _Pagos({required this.historial});

  /// Como lo entrega la base: el más reciente primero.
  final List<MovimientoData> historial;

  @override
  pw.Widget build(pw.Context context) {
    final cronologico = historial.reversed.toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _Etiqueta('PAGOS'),
        pw.SizedBox(height: 4),
        for (final (indice, movimiento) in cronologico.indexed)
          if (movimiento.huboAbono)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: _Pago(movimiento: movimiento, esAdelanto: indice == 0),
            ),
      ],
    );
  }
}

/// Un cobro: cuándo, de qué y cuánto; debajo, si fue en efectivo, con
/// cuánto pagó y su cambio.
class _Pago extends pw.StatelessWidget {
  _Pago({required this.movimiento, required this.esAdelanto});

  final MovimientoData movimiento;

  /// El más antiguo es el del alta: su cobro es el adelanto.
  final bool esAdelanto;

  @override
  pw.Widget build(pw.Context context) {
    final efectivo = TicketPdf.efectivoRecibido(movimiento);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '${movimiento.fecha.formatFullDate}  ·  '
                '${esAdelanto ? 'Adelanto' : 'Pago'} en '
                '${movimiento.metodoPago.value.toLowerCase()}',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
            pw.Text(movimiento.monto.enPesos),
          ],
        ),
        if (efectivo != null) _Pequeno(efectivo, centrado: false),
      ],
    );
  }
}

/// Lo que se anotó al recibir la ropa.
class _Nota extends pw.StatelessWidget {
  _Nota({required this.nota});

  final String nota;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _Etiqueta('NOTA'),
        pw.SizedBox(height: 2),
        pw.Text(nota, style: const pw.TextStyle(fontSize: 7.5)),
      ],
    );
  }
}

/// El agradecimiento y en qué punto quedó la orden.
class _Despedida extends pw.StatelessWidget {
  _Despedida({required this.orden});

  final OrdenDetalleData orden;

  @override
  pw.Widget build(pw.Context context) {
    final estado = switch (orden.estatus) {
      EstatusOrdenType.cerrada => 'Orden pagada y entregada',
      EstatusOrdenType.cancelada => 'Orden cancelada',
      _ when orden.todoEntregado => 'Ropa entregada',
      _ => 'Presente este ticket para recoger su ropa',
    };

    return pw.Column(
      children: [
        pw.Text(
          '¡Gracias por su preferencia!',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        _Pequeno(estado, arriba: 2),
      ],
    );
  }
}

/// Una etiqueta a la izquierda y su valor a la derecha.
class _Renglon extends pw.StatelessWidget {
  _Renglon(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: const pw.TextStyle(color: _Tinta.tenue)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(valor, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }
}

/// El título de una sección, en mayúsculas y gris.
class _Etiqueta extends pw.StatelessWidget {
  _Etiqueta(this.texto);

  final String texto;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Text(
      texto,
      style: pw.TextStyle(
        fontSize: 7,
        letterSpacing: 0.8,
        color: _Tinta.tenue,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }
}

/// Texto secundario, en chico y gris.
class _Pequeno extends pw.StatelessWidget {
  _Pequeno(this.texto, {this.arriba = 0, this.centrado = true});

  final String texto;
  final double arriba;
  final bool centrado;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: arriba),
      child: pw.Text(
        texto,
        textAlign: centrado ? pw.TextAlign.center : pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: 7, color: _Tinta.tenue),
      ),
    );
  }
}

/// La línea punteada entre secciones, como la de un ticket de papel.
class _Separador extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Divider(
        height: 1,
        thickness: 0.6,
        color: _Tinta.linea,
        borderStyle: pw.BorderStyle.dashed,
      ),
    );
  }
}

/// Los grises del ticket. Sin color: las impresoras de ticket son de una
/// tinta, y un gris claro es lo único que distinguen además del negro.
abstract final class _Tinta {
  static const texto = PdfColors.black;
  static const tenue = PdfColor.fromInt(0xFF555555);
  static const linea = PdfColor.fromInt(0xFF999999);
  static const resalte = PdfColor.fromInt(0xFFEEEEEE);
}

/// `2`, no `2.0`; pero `1.5` cuando se cobra por kilo.
String _cantidad(double cantidad) => cantidad == cantidad.roundToDouble()
    ? cantidad.toStringAsFixed(0)
    : cantidad.toStringAsFixed(1);
