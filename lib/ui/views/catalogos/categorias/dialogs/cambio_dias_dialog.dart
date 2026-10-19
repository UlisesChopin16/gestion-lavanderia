import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/int_ext.dart';

/// Qué hacer con los conceptos de una categoría a la que se le cambiaron los
/// días de entrega.
enum CambioDeDias {
  /// Los conceptos pasan a los días nuevos, con la categoría.
  propagar,

  /// Sólo cambia la categoría; sus conceptos conservan los suyos.
  soloCategoria,

  /// No se guarda nada.
  cancelar,
}

/// Pregunta hasta dónde llega un cambio de días de entrega.
///
/// Son tres caminos y no dos porque "no" es ambiguo: puede significar "no
/// toques los conceptos" o "déjalo todo como estaba". Antes la pregunta era un
/// aviso de sí o no, y decir que no cancelaba el guardado entero —ni siquiera
/// se podía corregir el nombre de la categoría sin arrastrar a sus conceptos—.
///
/// Dice cuántos conceptos están en juego, porque es lo que decide la
/// respuesta: propagar sobre dos es trivial y sobre cincuenta no.
///
/// Se cierra devolviendo la decisión; con Escape o tocando fuera devuelve
/// `null`, que quien llama trata como [CambioDeDias.cancelar].
class CambioDiasDialog extends StatelessWidget {
  const CambioDiasDialog({
    super.key,
    required this.categoria,
    required this.diasAnteriores,
    required this.diasNuevos,
    required this.conceptos,
  });

  final String categoria;
  final int diasAnteriores;
  final int diasNuevos;

  /// Cuántos conceptos cuelgan de la categoría.
  final int conceptos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog.adaptive(
      icon: const Icon(Icons.event_repeat_rounded),
      title: const Text(
        'Cambiaron los días de entrega',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Text(
            '"$categoria" pasa de ${diasAnteriores.enDias} a '
            '${diasNuevos.enDias}.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            conceptos == 1
                ? 'Tiene 1 concepto. ¿También cambia sus días?'
                : 'Tiene $conceptos conceptos. ¿También cambian sus días?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      // Los tres caminos van de lo que menos cambia a lo que más, y el que más
      // cambia es el que se ofrece lleno: es el que se elige casi siempre.
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(CambioDeDias.cancelar),
          child: Text(
            'Cancelar',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.redAccent,
            ),
          ),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(CambioDeDias.soloCategoria),
          child: const Text('Sólo la categoría'),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(CambioDeDias.propagar),
          child: const Text('Sí, cambiar también'),
        ),
      ],
    );
  }
}
