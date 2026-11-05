import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/corte_caja_view_model.dart';

/// Pide el día del corte de caja y lo genera en PDF.
///
/// El calendario va abierto en el propio diálogo, con hoy elegido: casi
/// siempre el corte es del día, y así basta con un toque para generarlo.
///
/// Se cierra devolviendo lo que se hizo, dicho para el aviso, o `null` si se
/// canceló.
class CorteCajaDialog extends ConsumerWidget {
  const CorteCajaDialog({super.key});

  static const double _anchoMaximo = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(corteCajaViewModelProvider);
    final notifier = ref.read(corteCajaViewModelProvider.notifier);
    final hoy = DateTime.now().soloDia;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoMaximo),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Encabezado(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    CalendarDatePicker(
                      initialDate: estado.dia,
                      firstDate: DateTime(2000),
                      lastDate: hoy,
                      onDateChanged: notifier.elegirDia,
                    ),
                    _DiaElegido(dia: estado.dia, esHoy: estado.dia == hoy),
                    if (estado.mensajeError.isNotEmpty)
                      _Error(mensaje: estado.mensajeError),
                  ],
                ),
              ),
            ),
            _Pie(
              generando: estado.generando,
              onGenerar: () => _generar(context, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generar(
    BuildContext context,
    CorteCajaViewModel notifier,
  ) async {
    final mensaje = await notifier.generar();

    if (mensaje == null || !context.mounted) return;

    Navigator.of(context).pop(mensaje);
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Column(
        spacing: 8,
        children: [
          Icon(Icons.savings_rounded, color: theme.colorScheme.secondary),
          Text(
            'Corte de caja',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// De qué día sale el corte, dicho completo para no equivocarse de día.
class _DiaElegido extends StatelessWidget {
  const _DiaElegido({required this.dia, required this.esHoy});

  final DateTime dia;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colorTexto = scheme.onSecondaryContainer;
    final fecha = dia.formatLongDate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.event_rounded, color: colorTexto),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  esHoy ? 'Hoy, $fecha' : 'El $fecha',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorTexto,
                  ),
                ),
                Text(
                  'Todo lo que se cobró ese día, de cualquier orden.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorTexto),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      mensaje,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.generando, required this.onGenerar});

  final bool generando;
  final VoidCallback onGenerar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: scheme.error)),
          ),
          FilledButton.icon(
            onPressed: generando ? null : onGenerar,
            icon: generando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_rounded),
            label: const Text('Generar PDF'),
          ),
        ],
      ),
    );
  }
}
