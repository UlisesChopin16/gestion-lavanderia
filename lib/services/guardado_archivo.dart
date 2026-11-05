import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

/// Guarda un archivo donde el usuario elija, con el diálogo "Guardar como",
/// y lo abre con el programa que Windows tenga para él: quien guarda un
/// ticket o un reporte casi siempre quiere verlo enseguida.
///
/// Registrado en el contenedor porque abre un diálogo del sistema.
class GuardadoArchivo {
  const GuardadoArchivo();

  /// Devuelve dónde quedó, o `null` si se cerró el diálogo sin guardar.
  /// Ya guardado, lo abre.
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
    await abrir(destino);

    return destino;
  }

  /// Escribe [bytes] junto a [hermano] —en su carpeta y con su nombre—, con
  /// otra [extension]. Es el Excel que acompaña al PDF de un reporte: el
  /// usuario eligió dónde guardar uno, y no tiene por qué elegirlo dos veces.
  ///
  /// Devuelve dónde quedó. Ya guardado, lo abre, igual que el primero.
  Future<String> guardarJunto(
    Uint8List bytes, {
    required String hermano,
    required String extension,
  }) async {
    final destino = p.setExtension(hermano, '.$extension');
    await File(destino).writeAsBytes(bytes, flush: true);
    await abrir(destino);

    return destino;
  }

  /// Abre [ruta] con el programa predeterminado del sistema, sin esperar a
  /// que se cierre.
  ///
  /// Si no se puede abrir no es un error para quien guardó: el archivo ya
  /// quedó donde lo pidió, y el aviso le dice dónde.
  Future<void> abrir(String ruta) async {
    try {
      if (Platform.isWindows) {
        // `explorer` devuelve 1 aunque lo haya abierto: su código no dice
        // nada, y por eso no se revisa.
        await Process.start('explorer.exe', [ruta]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [ruta]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [ruta]);
      }
    } on ProcessException catch (error) {
      debugPrint('No se pudo abrir $ruta.\n$error');
    }
  }
}
