import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/form_text_field.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/widgets/medidas_formulario.dart';

/// La cuenta de correo desde la que se envían los tickets.
///
/// Es opcional, y lo dice arriba: quien no la necesite tiene que poder dejarla
/// vacía sin preguntarse si le falta algo. Lo que sí necesita quien la llena
/// es saber qué poner, porque "servidor SMTP" y "contraseña de aplicación" no
/// son cosas que se sepan de memoria; de ahí la explicación y el atajo para
/// Gmail, que es lo que usan casi todos.
class DatosCorreoForm extends ConsumerWidget {
  const DatosCorreoForm({super.key, required this.anchoCampo});

  final double anchoCampo;

  /// Los dígitos del puerto más alto: 65535.
  static const _digitosPuerto = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final (cuenta, editable, passwordVisible, errores) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (
          estado.empresa.correoEnvio,
          estado.editable,
          estado.passwordCorreoVisible,
          estado.errores,
        ),
      ),
    );

    void cambiar(CorreoEnvioData nueva) => notifier.cambiarCorreoEnvio(nueva);

    return Column(
      spacing: MedidasFormulario.separacion,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Explicacion(
          onUsarGmail: editable
              ? () => cambiar(
                  cuenta.copyWith(
                    servidor: _Gmail.servidor,
                    puerto: CorreoEnvioData.puertoSsl,
                  ),
                )
              : null,
        ),
        Wrap(
          spacing: MedidasFormulario.separacion,
          runSpacing: MedidasFormulario.separacion,
          alignment: WrapAlignment.center,
          children: [
            FormTextField(
              value: cuenta.servidor,
              onChanged: (servidor) =>
                  cambiar(cuenta.copyWith(servidor: servidor)),
              enabled: editable,
              width: anchoCampo,
              label: 'Servidor SMTP',
              hint: _Gmail.servidor,
              icon: Icons.dns_rounded,
              errorText: errores[CampoEmpresa.smtpServidor],
              keyboardType: TextInputType.url,
            ),
            FormTextField(
              value: cuenta.puertoTexto,
              // Lo que no sea número queda en cero, que la validación marca
              // como faltante.
              onChanged: (puerto) =>
                  cambiar(cuenta.copyWith(puerto: int.tryParse(puerto) ?? 0)),
              enabled: editable,
              width: anchoCampo,
              label: 'Puerto',
              hint: '${CorreoEnvioData.puertoSsl}',
              icon: Icons.settings_ethernet_rounded,
              errorText: errores[CampoEmpresa.smtpPuerto],
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_digitosPuerto),
              ],
            ),
            FormTextField(
              value: cuenta.usuario,
              onChanged: (usuario) =>
                  cambiar(cuenta.copyWith(usuario: usuario)),
              enabled: editable,
              width: anchoCampo,
              label: 'Correo de la cuenta',
              hint: 'tickets@gmail.com',
              icon: Icons.alternate_email_rounded,
              errorText: errores[CampoEmpresa.smtpUsuario],
              keyboardType: TextInputType.emailAddress,
            ),
            FormTextField(
              value: cuenta.password,
              onChanged: (password) =>
                  cambiar(cuenta.copyWith(password: password)),
              enabled: editable,
              width: anchoCampo,
              label: 'Contraseña de aplicación',
              hint: 'No la contraseña de la cuenta',
              icon: Icons.key_rounded,
              errorText: errores[CampoEmpresa.smtpPassword],
              obscureText: !passwordVisible,
              suffix: IconButton(
                isSelected: passwordVisible,
                tooltip: passwordVisible
                    ? 'Ocultar la contraseña'
                    : 'Mostrar la contraseña',
                icon: Icon(
                  passwordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: editable
                    ? notifier.alternarPasswordCorreoVisible
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Los datos de la cuenta que casi todas las lavanderías van a usar.
abstract final class _Gmail {
  static const servidor = 'smtp.gmail.com';
}

/// Para qué sirve la sección y qué poner, con el atajo de Gmail.
class _Explicacion extends StatelessWidget {
  const _Explicacion({required this.onUsarGmail});

  /// En `null` mientras la pantalla está protegida.
  final VoidCallback? onUsarGmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  'Opcional. Es la cuenta desde la que se envían los '
                  'tickets a los clientes.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Con Gmail: servidor smtp.gmail.com, puerto 465 y una '
                  'contraseña de aplicación, que se crea en tu cuenta de '
                  'Google en Seguridad › Contraseñas de aplicaciones (hace '
                  'falta tener activa la verificación en dos pasos). La '
                  'contraseña se guarda cifrada en este equipo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onUsarGmail,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text('Usar los datos de Gmail'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
