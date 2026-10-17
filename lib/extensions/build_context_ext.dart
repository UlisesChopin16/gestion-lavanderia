import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogs.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

extension BuildContextExt on BuildContext {
  /// Aviso de que algo salió bien. Se espera a que se cierre para que dos
  /// mensajes seguidos no se pisen.
  Future<void> showSuccessDialog(String message) async {
    await showDialog<bool>(
      context: this,
      builder: (context) => SuccessDialog(message: message),
    );
  }

  Future<void> showErrorDialog(String message) async {
    await showDialog<bool>(
      context: this,
      builder: (context) => ErrorDialog(message: message),
    );
  }

  /// Pide confirmación antes de una acción.
  ///
  /// Devuelve `false` —y no `null`— cuando el diálogo se cierra sin elegir,
  /// para que quien llama no tenga que comparar contra `true`.
  Future<bool> showWarningDialog({
    String title = 'Advertencia',
    String message = '',
  }) async {
    final response = await showDialog<bool>(
      context: this,
      builder: (context) => WarningDialog(title: title, message: message),
    );

    return response ?? false;
  }

  /// Si la ventana es angosta: el ancho a partir del que las pantallas pasan a
  /// su versión compacta.
  bool get isSmallScreen =>
      MediaQuery.sizeOf(this).width < ConstantsManager.mediumScreen;
}
