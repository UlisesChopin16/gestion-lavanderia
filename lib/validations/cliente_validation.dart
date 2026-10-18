import 'package:gestion_lavanderia/extensions/string_ext.dart';

/// Los campos del formulario de un cliente que se validan.
enum CampoCliente { nombres, apellidos, telefono, correo }

/// Los dígitos que tiene un teléfono. El campo no deja escribir más, pero una
/// captura a medias llega hasta aquí.
const int _digitosTelefono = 10;

/// Qué le falta al cliente capturado para poder guardarse.
///
/// Devuelve el motivo por campo —y no un solo texto con el primer error, como
/// hacía la versión anterior— para que el formulario marque cada uno en su
/// lugar y se corrijan todos de una vez.
///
/// El correo es opcional: un cliente de mostrador muchas veces sólo deja su
/// teléfono. Si trae algo, tiene que parecer un correo.
Map<CampoCliente, String> validarCliente({
  required String nombres,
  required String apellidos,
  required String telefono,
  required String correo,
}) {
  final telefonoLimpio = telefono.trim();
  final correoLimpio = correo.trim();

  return {
    if (nombres.normalizeSpaces().isEmpty)
      CampoCliente.nombres: 'El nombre es obligatorio',
    if (apellidos.normalizeSpaces().isEmpty)
      CampoCliente.apellidos: 'Los apellidos son obligatorios',
    if (telefonoLimpio.isEmpty)
      CampoCliente.telefono: 'El teléfono es obligatorio'
    else if (telefonoLimpio.length != _digitosTelefono)
      CampoCliente.telefono: 'El teléfono debe tener $_digitosTelefono dígitos',
    if (correoLimpio.isNotEmpty && !correoLimpio.isEmail)
      CampoCliente.correo: 'El correo no es válido',
  };
}
