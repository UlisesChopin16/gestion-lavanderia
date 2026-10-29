import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';

/// De quién es la orden y cuándo se recibió.
///
/// Lleva el teléfono y el correo y no sólo el nombre: el detalle se abre casi
/// siempre para avisarle al cliente de algo —que su ropa está lista, que
/// debe— y así no hay que ir al catálogo a buscarlo.
class FichaCliente extends StatelessWidget {
  const FichaCliente({
    super.key,
    required this.nombre,
    required this.telefono,
    required this.correo,
    required this.recibida,
  });

  final String nombre;

  /// Vacío cuando el cliente no lo dio: entonces no se enseña el renglón.
  final String telefono;
  final String correo;

  final DateTime recibida;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary,
            child: Icon(Icons.person_rounded, color: scheme.onPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(nombre, style: theme.textTheme.titleMedium),
                if (telefono.isNotEmpty)
                  _Contacto(icono: Icons.phone_rounded, texto: telefono),
                if (correo.isNotEmpty)
                  _Contacto(icono: Icons.mail_outline_rounded, texto: correo),
                _Contacto(
                  icono: Icons.schedule_rounded,
                  texto: 'Recibida el ${recibida.formatFullDate}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      spacing: 6,
      children: [
        Icon(icono, size: 14, color: color),
        Flexible(
          child: Text(
            texto,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Lo que se anotó al recibir la ropa: una mancha, una prenda delicada.
///
/// Va resaltada porque casi siempre es una advertencia para quien entrega, y
/// una nota que se lee como el resto del texto es una nota que no se lee.
class NotaOrden extends StatelessWidget {
  const NotaOrden({super.key, required this.nota});

  final String nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 20,
            color: scheme.onTertiaryContainer,
          ),
          Expanded(
            child: Text(
              nota,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
