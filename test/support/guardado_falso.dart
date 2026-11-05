import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/services/guardado_archivo.dart';

/// Sin diálogo del sistema: anota qué le pidieron guardar.
class GuardadoFalso extends GuardadoArchivo {
  Uint8List? bytes;
  String? nombre;
  String? extension;

  /// En `true`, hace como si se cerrara el diálogo sin guardar.
  bool cancelar = false;

  @override
  Future<String?> guardar(
    Uint8List bytes, {
    required String nombre,
    required String extension,
    required String titulo,
  }) async {
    if (cancelar) return null;

    this.bytes = bytes;
    this.nombre = nombre;
    this.extension = extension;
    return 'C:/Reportes/$nombre';
  }

  /// Lo que se guardó junto al primero: el Excel.
  Uint8List? bytesJunto;
  String? rutaJunto;

  @override
  Future<String> guardarJunto(
    Uint8List bytes, {
    required String hermano,
    required String extension,
  }) async {
    bytesJunto = bytes;
    rutaJunto = hermano.replaceFirst(RegExp(r'\.[^.]+$'), '.$extension');
    return rutaJunto!;
  }
}

/// El botón de la tarjeta de la sección de reportes que lleva [titulo]: hay
/// uno por tarjeta, y cada uno dice lo suyo.
Finder botonDeLaTarjeta(String titulo) => find.descendant(
  of: find.ancestor(of: find.text(titulo), matching: find.byType(Card)),
  matching: find.byType(FilledButton),
);
