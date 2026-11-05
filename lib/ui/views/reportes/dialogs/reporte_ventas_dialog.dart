import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/date_range_picker.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/reporte_ventas_view_model.dart';

/// Pide el periodo del reporte general de ventas y lo genera.
///
/// Antes de generar dice qué días abarca. Sale siempre en PDF; el Excel es
/// opcional, para quien quiera filtrar y sumar en una hoja de cálculo.
///
/// Se cierra devolviendo lo que se hizo, dicho para el aviso, o `null` si se
/// canceló.
class ReporteVentasDialog extends ConsumerWidget {
  const ReporteVentasDialog({super.key});

  static const double _anchoMaximo = 520;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(reporteVentasViewModelProvider);
    final notifier = ref.read(reporteVentasViewModelProvider.notifier);
    final rango = estado.rangoAl(DateTime.now());

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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    _Periodos(
                      elegido: estado.periodo,
                      onElegir: notifier.elegirPeriodo,
                    ),
                    if (estado.periodo == PeriodoReporte.rango)
                      DateRangePicker(
                        labelText: 'Fechas del reporte',
                        selectedDates: estado.fechas,
                        changeDate: notifier.elegirFechas,
                        onDelete: () => notifier.elegirFechas(const []),
                      ),
                    _Resumen(rango: rango),
                    _OpcionExcel(
                      elegida: estado.tambienExcel,
                      onCambiar: notifier.pedirExcel,
                    ),
                    if (estado.mensajeError.isNotEmpty)
                      _Error(mensaje: estado.mensajeError),
                  ],
                ),
              ),
            ),
            _Pie(
              listo: rango != null,
              conExcel: estado.tambienExcel,
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
    ReporteVentasViewModel notifier,
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        spacing: 8,
        children: [
          Icon(Icons.point_of_sale_rounded, color: theme.colorScheme.secondary),
          Text(
            'Reporte general de ventas',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// Los periodos como etiquetas: se ven todos y se elige con un toque.
class _Periodos extends StatelessWidget {
  const _Periodos({required this.elegido, required this.onElegir});

  final PeriodoReporte elegido;
  final ValueChanged<PeriodoReporte> onElegir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('Periodo', style: theme.textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final periodo in PeriodoReporte.values)
              ChoiceChip(
                label: Text(periodo.titulo),
                selected: periodo == elegido,
                onSelected: (_) => onElegir(periodo),
              ),
          ],
        ),
      ],
    );
  }
}

/// Qué días abarca el reporte.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.rango});

  /// En `null` mientras falten las fechas.
  final RangoReporte? rango;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rango = this.rango;
    final colorTexto = scheme.onSecondaryContainer;

    final (icono, dias) = rango == null
        ? (Icons.event_rounded, 'Elige las fechas del reporte.')
        : (Icons.date_range_rounded, _dias(rango));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(icono, color: colorTexto),
          Expanded(
            child: Text(
              dias,
              style: theme.textTheme.titleSmall?.copyWith(color: colorTexto),
            ),
          ),
        ],
      ),
    );
  }

  static String _dias(RangoReporte rango) => rango.desde == rango.hasta
      ? 'El ${rango.desde.formatDate}'
      : 'Del ${rango.desde.formatDate} al ${rango.hasta.formatDate}';
}

/// Si además del PDF se quiere el Excel.
class _OpcionExcel extends StatelessWidget {
  const _OpcionExcel({required this.elegida, required this.onCambiar});

  final bool elegida;
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: elegida,
      onChanged: (valor) => onCambiar(valor ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('También en Excel'),
      subtitle: const Text(
        'Para filtrar y sumar las órdenes en una hoja de cálculo. Se guarda '
        'junto al PDF, con el mismo nombre.',
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

/// Cancelar y generar. El botón dice qué archivos salen.
class _Pie extends StatelessWidget {
  const _Pie({
    required this.listo,
    required this.conExcel,
    required this.generando,
    required this.onGenerar,
  });

  /// Si ya hay fechas: sin ellas no hay qué generar.
  final bool listo;

  final bool conExcel;
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
            onPressed: !listo || generando ? null : onGenerar,
            icon: generando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_rounded),
            label: Text(conExcel ? 'Generar PDF y Excel' : 'Generar PDF'),
          ),
        ],
      ),
    );
  }
}
