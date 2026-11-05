import 'dart:io';

import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:pdf/widgets.dart' as pw;

/// El logo de la empresa listo para un PDF: el ticket y los reportes.
abstract final class LogoPdf {
  /// El logo, o `null` si no tiene o el archivo ya no está. Un logo que
  /// falta no impide el documento: sale sin él.
  static Future<pw.MemoryImage?> de(EmpresaData? empresa) async {
    final ruta = empresa?.logo;
    if (ruta == null || ruta.isEmpty) return null;

    try {
      return pw.MemoryImage(await File(ruta).readAsBytes());
    } on FileSystemException {
      return null;
    }
  }
}
