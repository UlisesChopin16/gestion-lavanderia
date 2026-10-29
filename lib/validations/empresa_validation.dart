import 'package:collection/collection.dart' show MapEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';

/// Los campos del formulario de configuración que se validan.
///
/// La validación devuelve el motivo por campo para que la pantalla marque cada
/// uno en su lugar. La versión anterior devolvía un solo texto con el primer
/// error y lo mostraba en un diálogo: había que corregir y volver a guardar una
/// vez por campo para enterarse del siguiente.
enum CampoEmpresa {
  nombre,
  telefono,
  correo,
  password,
  calle,
  numeroExterior,
  colonia,
  codigoPostal,
  ciudad,
  estado,
  smtpServidor,
  smtpPuerto,
  smtpUsuario,
  smtpPassword,
}

/// Los campos mal capturados, con el motivo de cada uno.
///
/// Envuelve el mapa en lugar de dejarlo suelto en el estado del formulario, que
/// es una clase de freezed: la versión instalada (3.2.3) genera código inválido
/// para un campo `Map` —le pone `final` a un parámetro con nombre, que Dart
/// 3.13 ya no acepta—. De paso la pantalla consulta `errores[campo]` y
/// `errores.hay` sin saber que detrás hay un mapa.
@immutable
class ErroresEmpresa {
  const ErroresEmpresa(this._motivos);

  const ErroresEmpresa.ninguno() : _motivos = const {};

  final Map<CampoEmpresa, String> _motivos;

  static const _igualdad = MapEquality<CampoEmpresa, String>();

  /// Por qué está mal [campo], o `null` si está bien.
  String? operator [](CampoEmpresa campo) => _motivos[campo];

  bool get hay => _motivos.isNotEmpty;

  Iterable<CampoEmpresa> get campos => _motivos.keys;

  /// Los errores de [campos] nada más.
  ///
  /// Con esto el formulario conserva las marcas que ya mostró y no estrena
  /// otras mientras se escribe.
  ErroresEmpresa soloDe(Iterable<CampoEmpresa> campos) =>
      ErroresEmpresa({for (final campo in campos) campo: ?_motivos[campo]});

  @override
  bool operator ==(Object other) =>
      other is ErroresEmpresa && _igualdad.equals(_motivos, other._motivos);

  @override
  int get hashCode => _igualdad.hash(_motivos);

  @override
  String toString() => 'ErroresEmpresa($_motivos)';
}

/// El código postal más bajo que se puede escribir con cinco dígitos.
///
/// La columna es entera, así que 01000 se guarda como 1000: el límite inferior
/// es 1000 y no 10000 para no rechazar los códigos que empiezan con cero.
const int _codigoPostalMinimo = 1000;
const int _codigoPostalMaximo = 99999;

/// El puerto más alto que existe: el campo es de 16 bits.
const int _puertoMaximo = 65535;

/// Los dígitos de un teléfono. El campo ya no deja escribir más, pero una
/// captura a medias llega hasta aquí.
const int _digitosTelefono = 10;

/// Qué le falta a [empresa] para poder guardarse.
///
/// `paginaWeb` y el número interior no aparecen porque son opcionales, y el
/// correo sólo se revisa si trae algo.
///
/// La cuenta de correo para enviar tickets también es opcional, pero va
/// completa o no va: con un campo escrito se piden los cuatro, porque una
/// cuenta a medias no envía nada y el error saldría hasta el mostrador, con
/// un cliente esperando su ticket.
ErroresEmpresa validarEmpresa(EmpresaData empresa) {
  final direccion = empresa.direccion;
  final telefono = empresa.telefono.trim();
  final correo = empresa.correo.trim();
  final cuenta = empresa.correoEnvio;
  final usuario = cuenta.usuario.trim();

  return ErroresEmpresa({
    if (empresa.nombre.trim().isEmpty)
      CampoEmpresa.nombre: 'El nombre es obligatorio',
    if (telefono.isEmpty)
      CampoEmpresa.telefono: 'El teléfono es obligatorio'
    else if (telefono.length != _digitosTelefono)
      CampoEmpresa.telefono: 'El teléfono debe tener $_digitosTelefono dígitos',
    if (correo.isNotEmpty && !correo.isEmail)
      CampoEmpresa.correo: 'El correo no es válido',
    if (empresa.password.trim().isEmpty)
      CampoEmpresa.password: 'La contraseña es obligatoria',
    if (direccion.calle.trim().isEmpty)
      CampoEmpresa.calle: 'La calle es obligatoria',
    if (direccion.numeroExterior.trim().isEmpty)
      CampoEmpresa.numeroExterior: 'El número exterior es obligatorio',
    if (direccion.colonia.trim().isEmpty)
      CampoEmpresa.colonia: 'La colonia es obligatoria',
    if (direccion.codigoPostal <= 0)
      CampoEmpresa.codigoPostal: 'El código postal es obligatorio'
    else if (direccion.codigoPostal < _codigoPostalMinimo ||
        direccion.codigoPostal > _codigoPostalMaximo)
      CampoEmpresa.codigoPostal: 'El código postal debe tener 5 dígitos',
    if (direccion.ciudad.trim().isEmpty)
      CampoEmpresa.ciudad: 'La ciudad es obligatoria',
    if (direccion.estado.trim().isEmpty)
      CampoEmpresa.estado: 'El estado es obligatorio',
    if (!cuenta.vacia) ...{
      if (cuenta.servidor.trim().isEmpty)
        CampoEmpresa.smtpServidor: 'Falta el servidor de correo',
      if (cuenta.puerto <= 0)
        CampoEmpresa.smtpPuerto: 'Falta el puerto'
      else if (cuenta.puerto > _puertoMaximo)
        CampoEmpresa.smtpPuerto: 'El puerto no es válido',
      if (usuario.isEmpty)
        CampoEmpresa.smtpUsuario: 'Falta el correo de la cuenta'
      else if (!usuario.isEmail)
        CampoEmpresa.smtpUsuario: 'El correo no es válido',
      if (cuenta.password.isEmpty)
        CampoEmpresa.smtpPassword: 'Falta la contraseña de aplicación',
    },
  });
}
