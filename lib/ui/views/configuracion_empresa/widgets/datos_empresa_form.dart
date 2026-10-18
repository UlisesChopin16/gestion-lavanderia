import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/form_text_field.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/widgets/medidas_formulario.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Los datos de contacto de la empresa.
class DatosEmpresaForm extends ConsumerWidget {
  const DatosEmpresaForm({super.key, required this.anchoCampo});

  final double anchoCampo;

  /// Los dígitos que acepta el teléfono. La validación exige exactamente
  /// estos; el formateador evita que se puedan escribir más.
  static const _digitosTelefono = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final (empresa, editable, passwordVisible, errores) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (
          estado.empresa,
          estado.editable,
          estado.passwordVisible,
          estado.errores,
        ),
      ),
    );

    return Column(
      spacing: MedidasFormulario.separacion,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormTextField(
          value: empresa.nombre,
          onChanged: notifier.cambiarNombre,
          enabled: editable,
          width: anchoCampo,
          label: 'Nombre de la empresa',
          hint: 'Lavandería El Sol',
          icon: IconsManager.selectedEmpresaIcon,
          errorText: errores[CampoEmpresa.nombre],
        ),
        FormTextField(
          value: empresa.telefono,
          onChanged: notifier.cambiarTelefono,
          enabled: editable,
          width: anchoCampo,
          label: 'Teléfono',
          hint: '10 dígitos',
          icon: Icons.phone_rounded,
          errorText: errores[CampoEmpresa.telefono],
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_digitosTelefono),
          ],
        ),
        FormTextField(
          value: empresa.correo,
          onChanged: notifier.cambiarCorreo,
          enabled: editable,
          width: anchoCampo,
          label: 'Correo electrónico (opcional)',
          hint: 'contacto@lavanderia.com',
          icon: Icons.email_rounded,
          errorText: errores[CampoEmpresa.correo],
          keyboardType: TextInputType.emailAddress,
        ),
        FormTextField(
          value: empresa.paginaWeb,
          onChanged: notifier.cambiarPaginaWeb,
          enabled: editable,
          width: anchoCampo,
          label: 'Página web (opcional)',
          hint: 'www.lavanderia.com',
          icon: Icons.language_rounded,
          keyboardType: TextInputType.url,
        ),
        FormTextField(
          value: empresa.password,
          onChanged: notifier.cambiarPassword,
          enabled: editable,
          width: anchoCampo,
          label: 'Contraseña',
          hint: 'La que desbloquea esta pantalla',
          icon: Icons.lock_rounded,
          errorText: errores[CampoEmpresa.password],
          obscureText: !passwordVisible,
          suffix: IconButton(
            isSelected: passwordVisible,
            tooltip: passwordVisible
                ? 'Ocultar la contraseña'
                : 'Mostrar la contraseña',
            icon: Icon(
              passwordVisible ? Icons.visibility : Icons.visibility_off,
            ),
            // En sólo lectura no se descubre: el notificador lo impide, y aquí
            // el botón se ve deshabilitado para que se entienda por qué.
            onPressed: editable ? notifier.alternarPasswordVisible : null,
          ),
        ),
      ],
    );
  }
}
