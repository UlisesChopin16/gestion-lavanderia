import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/ticket/view_model/orden_ticket_view_model.dart';

/// A quién se envía el ticket, y el envío.
///
/// El envío ocurre aquí dentro y no después de cerrar: si el servidor lo
/// rechaza, el motivo se lee en el mismo diálogo y se reintenta sin volver a
/// escribir el correo. Se cierra devolviendo lo que se hizo, dicho para el
/// aviso, o `null` si se canceló.
///
/// Sin cuenta de correo configurada no enseña el campo: explica qué falta y
/// dónde se configura, porque un botón que falla al final del camino es peor
/// que decirlo al principio.
class EnviarTicketDialog extends ConsumerStatefulWidget {
  const EnviarTicketDialog({super.key, required this.ordenId});

  final int ordenId;

  @override
  ConsumerState<EnviarTicketDialog> createState() => _EnviarTicketDialogState();
}

class _EnviarTicketDialogState extends ConsumerState<EnviarTicketDialog> {
  /// Se crea en `initState` y no de forma perezosa: sin cuenta configurada el
  /// campo nunca se enseña, y un `late` se habría creado por primera vez en
  /// `dispose`, leyendo un provider con el widget ya desmontado.
  late final TextEditingController _correo;

  /// Si ya se intentó enviar: antes de eso, un correo a medio escribir no se
  /// marca como inválido.
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    _correo = TextEditingController(
      text: ref
          .read(ordenTicketViewModelProvider(widget.ordenId))
          .correoCliente,
    );
    // El error del envío anterior no es de este.
    Future.microtask(
      ref
          .read(ordenTicketViewModelProvider(widget.ordenId).notifier)
          .olvidarErrorCorreo,
    );
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(ordenTicketViewModelProvider(widget.ordenId));

    if (!estado.correoConfigurado) return const _CorreoSinConfigurar();

    final invalido = _intentado && !_correo.text.trim().isEmail;

    return AlertDialog(
      icon: const Icon(Icons.forward_to_inbox_rounded),
      title: const Text('Enviar el ticket por correo'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              'Se envía con el PDF adjunto desde '
              '${estado.empresa?.correoEnvio.usuario}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              controller: _correo,
              autofocus: true,
              enabled: !estado.enviando,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo del cliente',
                hintText: 'cliente@correo.com',
                prefixIcon: const Icon(Icons.email_rounded),
                errorText: invalido ? 'El correo no es válido' : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _enviar(),
            ),
            if (estado.errorCorreo.isNotEmpty)
              _ErrorEnvio(mensaje: estado.errorCorreo),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: estado.enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: estado.enviando ? null : _enviar,
          icon: estado.enviando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(estado.enviando ? 'Enviando…' : 'Enviar'),
        ),
      ],
    );
  }

  Future<void> _enviar() async {
    setState(() => _intentado = true);
    if (!_correo.text.trim().isEmail) return;

    final mensaje = await ref
        .read(ordenTicketViewModelProvider(widget.ordenId).notifier)
        .enviar(_correo.text);

    if (mensaje == null || !mounted) return;

    Navigator.of(context).pop(mensaje);
  }
}

/// Por qué no salió el correo, donde se está mirando.
class _ErrorEnvio extends StatelessWidget {
  const _ErrorEnvio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve en lugar del envío cuando la lavandería no tiene cuenta de
/// correo configurada.
class _CorreoSinConfigurar extends StatelessWidget {
  const _CorreoSinConfigurar();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.mail_lock_rounded),
      title: const Text('Falta la cuenta de correo'),
      content: const SizedBox(
        width: 400,
        child: Text(
          'Para enviar tickets por correo, primero configura la cuenta de la '
          'lavandería en Configuración de empresa, en la sección «Correo para '
          'enviar tickets». Mientras tanto puedes descargar el PDF y enviarlo '
          'tú.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
