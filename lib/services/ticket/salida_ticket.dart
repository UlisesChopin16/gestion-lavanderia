import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

/// Las imágenes de cada página de un PDF, para enseñarlo en pantalla.
///
/// Se rasteriza el PDF ya generado, en lugar de dibujar el ticket otra vez con
/// widgets: así la vista previa es el archivo, y no una imitación que se puede
/// desalinear de él.
///
/// Registrado en el contenedor porque rasterizar pide un motor nativo
/// (PDFium), que en las pruebas no existe.
class VistaPreviaPdf {
  const VistaPreviaPdf();

  /// Una resolución con la que el texto chico del ticket se lee nítido en una
  /// pantalla de escritorio, sin generar imágenes enormes.
  static const double _dpi = 200;

  Future<List<Uint8List>> paginas(Uint8List pdf) async {
    return [
      await for (final pagina in Printing.raster(pdf, dpi: _dpi))
        await pagina.toPng(),
    ];
  }
}

/// Guarda el ticket donde el usuario elija, con el diálogo "Guardar como".
///
/// Registrado en el contenedor porque abre un diálogo del sistema.
class GuardadoPdf {
  const GuardadoPdf();

  /// Devuelve dónde quedó, o `null` si se cerró el diálogo sin guardar.
  Future<String?> guardar(Uint8List pdf, {required String nombre}) {
    return const GuardadoArchivo().guardar(
      pdf,
      nombre: nombre,
      extension: 'pdf',
      titulo: 'Guardar el ticket',
    );
  }
}

/// Manda el ticket a una impresora con el diálogo de impresión del sistema.
///
/// Registrado en el contenedor porque abre un diálogo del sistema.
class ImpresionPdf {
  const ImpresionPdf();

  /// Devuelve si se mandó a imprimir: `false` si se cerró el diálogo.
  Future<bool> imprimir(Uint8List pdf, {required String nombre}) {
    return Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: nombre,
      format: PdfPageFormat.roll80,
      // El ticket ya viene armado a su medida: no se vuelve a acomodar al
      // papel que se elija en el diálogo.
      dynamicLayout: false,
    );
  }
}

/// Envía un correo con un PDF adjunto desde la cuenta de la lavandería.
///
/// Registrado en el contenedor porque sale a internet.
class EnvioCorreo {
  const EnvioCorreo();

  /// Lo que se espera al servidor antes de rendirse: sin límite, una red
  /// caída dejaba el botón girando para siempre.
  static const _espera = Duration(seconds: 30);

  /// Lanza [EnvioCorreoException] con un motivo que se puede enseñar.
  Future<void> enviar({
    required CorreoEnvioData cuenta,
    required String remitente,
    required String destinatario,
    required String asunto,
    required String html,
    required Uint8List adjunto,
    required String nombreAdjunto,
  }) async {
    final usuario = cuenta.usuario.trim();
    final servidor = SmtpServer(
      cuenta.servidor.trim(),
      port: cuenta.puerto,
      username: usuario,
      password: cuenta.password,
      ssl: cuenta.puerto == CorreoEnvioData.puertoSsl,
    );
    final mensaje = Message()
      ..from = Address(usuario, remitente.isEmpty ? null : remitente)
      ..recipients.add(destinatario)
      ..subject = asunto
      ..html = html
      ..attachments = [
        StreamAttachment(
          Stream.value(adjunto),
          'application/pdf',
          fileName: nombreAdjunto,
        ),
      ];

    try {
      await send(mensaje, servidor, timeout: _espera);
    } on SmtpClientAuthenticationException {
      throw const EnvioCorreoException(
        'El servidor rechazó el correo o la contraseña de la cuenta. Revisa '
        'la contraseña de aplicación en Configuración de empresa.',
      );
    } on SocketException {
      throw const EnvioCorreoException(
        'No se pudo conectar con el servidor de correo. Revisa la conexión a '
        'internet, y el servidor y el puerto en Configuración de empresa.',
      );
    } on TimeoutException {
      throw const EnvioCorreoException(
        'El servidor de correo tardó demasiado en responder. Intenta de '
        'nuevo en un momento.',
      );
    } on MailerException catch (error) {
      final detalle = error.problems.map((problema) => problema.msg).join(' ');

      throw EnvioCorreoException(
        detalle.isEmpty
            ? 'El servidor de correo no aceptó el mensaje.'
            : 'El servidor de correo no aceptó el mensaje: $detalle',
      );
    }
  }
}

/// Por qué no salió un correo, dicho para quien atiende el mostrador.
class EnvioCorreoException implements Exception {
  const EnvioCorreoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'EnvioCorreoException: $mensaje';
}
