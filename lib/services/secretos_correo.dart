import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// La contraseña de la cuenta de correo, guardada cifrada fuera de la base.
///
/// No va en `app.db` con el resto de la configuración porque ese archivo se
/// abre con cualquier visor de SQLite, y la contraseña de aplicación de una
/// cuenta de correo da acceso a enviar mensajes en nombre de la lavandería. En
/// Windows `FlutterSecureStorage` la cifra con las credenciales del usuario del
/// sistema.
///
/// Está aparte, y registrada en el contenedor, para que el datasource no sepa
/// dónde vive la contraseña y una prueba pueda usar el almacén simulado.
class SecretosCorreo {
  const SecretosCorreo([this._almacen = const FlutterSecureStorage()]);

  final FlutterSecureStorage _almacen;

  static const _clave = 'correo_envio_password';

  /// La contraseña guardada, o vacía si no hay ninguna.
  Future<String> password() async => await _almacen.read(key: _clave) ?? '';

  /// Guarda [password]. Vacía la borra: quitar la cuenta de correo no debe
  /// dejar su contraseña olvidada en el equipo.
  Future<void> guardarPassword(String password) {
    if (password.isEmpty) return _almacen.delete(key: _clave);

    return _almacen.write(key: _clave, value: password);
  }
}
