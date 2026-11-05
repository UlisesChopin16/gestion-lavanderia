import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Guarda un archivo donde el usuario elija, con el diálogo "Guardar como".
///
/// Registrado en el contenedor porque abre un diálogo del sistema.
class GuardadoArchivo {
  const GuardadoArchivo();

  /// Devuelve dónde quedó, o `null` si se cerró el diálogo sin guardar.
  ///
  /// El archivo lo escribe este método y no el selector: si el usuario borra
  /// la extensión del nombre, se le repone, y un archivo sin ella no se abre
  /// con doble clic.
  Future<String?> guardar(
    Uint8List bytes, {
    required String nombre,
    required String extension,
    required String titulo,
  }) async {
    final ruta = await FilePicker.platform.saveFile(
      dialogTitle: titulo,
      fileName: nombre,
      type: FileType.custom,
      allowedExtensions: [extension],
      lockParentWindow: true,
    );
    if (ruta == null) return null;

    final destino = p.extension(ruta).toLowerCase() == '.$extension'
        ? ruta
        : '$ruta.$extension';
    await File(destino).writeAsBytes(bytes, flush: true);

    return destino;
  }
}
