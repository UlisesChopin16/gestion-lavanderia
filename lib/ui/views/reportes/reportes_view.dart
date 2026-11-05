import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/title_container.dart';
import 'package:gestion_lavanderia/ui/views/reportes/dialogs/reporte_ventas_dialog.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Reportes y estadísticas: una tarjeta por reporte que se puede sacar.
///
/// De momento es uno, el general de ventas. Van en tarjetas y no en una
/// lista porque cada uno se explica en dos renglones —qué trae y para qué
/// sirve— y así quedan los que se agreguen después, uno junto al otro.
class ReportesView extends StatelessWidget {
  const ReportesView({super.key});

  static const double _margen = 16;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_margen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            const TitleContainer(
              title: 'Reportes y estadísticas',
              icon: IconsManager.selectedReportesIcon,
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _TarjetaReporte(
                  icono: Icons.point_of_sale_rounded,
                  titulo: 'Reporte general de ventas',
                  descripcion:
                      'Cada orden del periodo con su total, lo pagado y lo '
                      'que falta. Después, el total cobrado, lo cobrado por '
                      'método de pago y contra lo pendiente, y el detalle de '
                      'cada pago.',
                  nota: 'Hasta un mes sale en PDF; más de un mes, en Excel.',
                  onGenerar: () => _reporteVentas(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reporteVentas(BuildContext context) async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (context) => const ReporteVentasDialog(),
    );

    if (mensaje == null || !context.mounted) return;

    await context.showSuccessDialog(mensaje);
  }
}

/// Un reporte: qué es, qué trae y el botón para sacarlo.
class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.nota,
    required this.onGenerar,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String nota;
  final VoidCallback onGenerar;

  /// Lo bastante ancha para que la descripción quepa en pocos renglones, y
  /// lo bastante angosta para que quepan dos o tres por fila.
  static const double _ancho = 380;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _ancho),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                spacing: 12,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(icono),
                  ),
                  Expanded(
                    child: Text(titulo, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              Text(descripcion, style: theme.textTheme.bodyMedium),
              Text(
                nota,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onGenerar,
                  icon: const Icon(Icons.description_rounded),
                  label: const Text('Generar reporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
