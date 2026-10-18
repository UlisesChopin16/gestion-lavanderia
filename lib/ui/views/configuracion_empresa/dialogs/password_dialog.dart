import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/base_dialog.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

/// Pide la contraseña para habilitar la edición de la configuración.
///
/// Se cierra devolviendo `true` sólo cuando la contraseña es la correcta; con
/// una equivocada se queda abierto y lo dice en el propio campo, que es donde
/// se está mirando.
class PasswordDialog extends ConsumerStatefulWidget {
  const PasswordDialog({super.key});

  @override
  ConsumerState<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<PasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: 'Editar la configuración',
      icon: const Icon(Icons.lock_rounded),
      closeText: 'Cancelar',
      actionText: 'Continuar',
      // El diálogo no se cierra solo: con la contraseña equivocada tiene que
      // quedarse abierto para avisarlo.
      closeOnAction: false,
      onActionPressed: _verificar,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const Text(
            'Escribe la contraseña de la empresa para desbloquear los datos.',
          ),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              errorText: _error,
            ),
            // Enter hace lo mismo que el botón: es lo que se espera de un
            // campo de contraseña.
            onSubmitted: (_) => _verificar(),
            onChanged: (_) => _limpiarError(),
          ),
        ],
      ),
    );
  }

  void _verificar() {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);

    if (notifier.habilitarEdicion(_controller.text)) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _error = 'La contraseña no coincide');
  }

  void _limpiarError() {
    if (_error == null) return;

    setState(() => _error = null);
  }
}
