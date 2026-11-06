import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/services/avisos/correo_ropa_lista.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';

/// Le avisa al cliente por correo que su ropa está lista.
///
/// Registrado en el contenedor porque sale a internet, y porque de él
/// depende si el aviso está encendido.
class AvisoRopaLista {
  const AvisoRopaLista(this._correo, {this.habilitado = false});

  final EnvioCorreo _correo;

  /// Apagado hasta que el dueño lo pida: mientras tanto, marcar ropa como
  /// lista sólo la marca, sin preguntar ni enviar nada. Se enciende al
  /// registrarlo en `ordenes_module.dart`.
  final bool habilitado;

  /// Si al marcar ropa como lista se le avisará al cliente: el aviso está
  /// encendido, la cuenta de correo de la lavandería está completa y el
  /// cliente tiene a dónde recibirlo.
  bool avisaA(OrdenDetalleData orden, EmpresaData? empresa) =>
      habilitado &&
      (empresa?.correoEnvio.completa ?? false) &&
      orden.clienteCorreo.trim().isNotEmpty;

  /// Envía el aviso con toda la ropa de [orden] que está lista y no se ha
  /// llevado. Lanza `EnvioCorreoException` con un motivo que se puede
  /// enseñar.
  Future<void> enviar(OrdenDetalleData orden, EmpresaData empresa) {
    return _correo.enviar(
      cuenta: empresa.correoEnvio,
      remitente: empresa.nombre,
      destinatario: orden.clienteCorreo.trim(),
      asunto: CorreoRopaLista.asunto(orden, empresa),
      html: CorreoRopaLista.html(orden, empresa),
    );
  }
}
