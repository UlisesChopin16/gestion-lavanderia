import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda el logo de la empresa junto a los datos de la aplicación.
///
/// La imagen se copia a la carpeta de la aplicación en lugar de guardar la
/// ruta donde el usuario la tenía: ese archivo puede estar en una memoria USB
/// o en Descargas, y el ticket dejaría de imprimir el logo el día que
/// desaparezca.
///
/// Está aparte del notificador —y se inyecta con un provider— para que la
/// pantalla se pueda probar sin abrir el diálogo del sistema.
class LogoStorage {
  const LogoStorage();

  static const carpeta = 'logos';

  static const extensionesPermitidas = ['jpg', 'jpeg', 'png'];

  /// Pide una imagen y la deja guardada. Devuelve la ruta nueva, o `null` si
  /// el usuario cerró el diálogo sin elegir.
  ///
  /// [rutaAnterior] es el logo que se reemplaza; se borra al final, cuando el
  /// nuevo ya está escrito, para no quedarse sin ninguno si la copia falla.
  Future<String?> elegirLogo({String? rutaAnterior}) async {
    final seleccion = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecciona el logo de la empresa',
      type: FileType.custom,
      allowedExtensions: extensionesPermitidas,
      lockParentWindow: true,
    );

    final archivos = seleccion?.files ?? const [];
    if (archivos.isEmpty) return null;

    final origen = archivos.first.path;
    if (origen == null) return null;

    final destino = await _rutaDestino(p.extension(origen));
    await File(origen).copy(destino);
    await _borrar(rutaAnterior, excepto: destino);

    return destino;
  }

  /// Una ruta nueva para cada logo, con la hora en el nombre.
  ///
  /// No se reescribe siempre el mismo archivo porque Flutter guarda las
  /// imágenes en caché por ruta: la pantalla seguiría mostrando el logo
  /// anterior hasta reiniciar la aplicación.
  Future<String> _rutaDestino(String extension) async {
    final directorio = await getApplicationDocumentsDirectory();
    final carpetaLogos = Directory(p.join(directorio.path, carpeta));

    await carpetaLogos.create(recursive: true);

    final nombre = 'logo_${DateTime.now().millisecondsSinceEpoch}$extension';

    return p.join(carpetaLogos.path, nombre);
  }

  /// Borra el logo reemplazado.
  ///
  /// Un archivo que no se pudo borrar no es motivo para fallar: el logo nuevo
  /// ya está guardado y lo único que queda es una imagen suelta en disco.
  Future<void> _borrar(String? ruta, {required String excepto}) async {
    if (ruta == null || ruta.isEmpty || ruta == excepto) return;

    try {
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } on FileSystemException {
      return;
    }
  }
}
