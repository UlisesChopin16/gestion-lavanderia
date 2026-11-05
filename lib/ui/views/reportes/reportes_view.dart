import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/title_container.dart';
import 'package:gestion_lavanderia/ui/views/reportes/corte/corte_caja_view.dart';
import 'package:gestion_lavanderia/ui/views/reportes/cuentas/cuentas_por_cobrar_view.dart';
import 'package:gestion_lavanderia/ui/views/reportes/dialogs/reporte_ventas_dialog.dart';
import 'package:gestion_lavanderia/ui/views/reportes/ropa/ropa_pendiente_view.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Reportes y estadísticas: una tarjeta por reporte que se puede sacar.
///
/// El corte de caja va primero porque es el de todos los días. Van en
/// tarjetas y no en una lista porque cada uno se explica en dos renglones
/// —qué trae y para qué sirve— y así quedan los que se agreguen después, uno
/// junto al otro.
///
/// El corte de caja, las cuentas por cobrar y la ropa pendiente no son
/// archivos sino pantallas con gráficas: se abren aquí mismo, en lugar de las
/// tarjetas, y su flecha regresa a ellas.
class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  static const double _margen = 16;

  /// La pantalla abierta; en `null`, las tarjetas.
  _Pantalla? _abierta;

  void _abrir(_Pantalla? pantalla) => setState(() => _abierta = pantalla);

  @override
  Widget build(BuildContext context) {
    if (_abierta case final abierta?) {
      void volver() => _abrir(null);

      return Scaffold(
        body: switch (abierta) {
          _Pantalla.corte => CorteCajaView(onVolver: volver),
          _Pantalla.cuentas => CuentasPorCobrarView(onVolver: volver),
          _Pantalla.ropa => RopaPendienteView(onVolver: volver),
        },
      );
    }

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
                  icono: Icons.savings_rounded,
                  titulo: 'Corte de caja',
                  descripcion:
                      'Todo lo que se cobró en un día, de cualquier orden: '
                      'el total, cuánto efectivo debe haber en la caja y '
                      'gráficas por hora, por método de pago y contra los '
                      'días anteriores. Al final, cada cobro.',
                  nota: 'Se ve en pantalla, día por día.',
                  accion: 'Ver el corte',
                  iconoAccion: Icons.insights_rounded,
                  onGenerar: () => _abrir(_Pantalla.corte),
                ),
                _TarjetaReporte(
                  icono: Icons.account_balance_wallet_rounded,
                  titulo: 'Cuentas por cobrar',
                  descripcion:
                      'Las órdenes que todavía deben algo: cuánto, desde '
                      'cuándo y quién, con su teléfono para llamarle. Lo que '
                      'lleva más de un mes, aparte.',
                  nota: 'Se ve en pantalla.',
                  accion: 'Ver las cuentas',
                  iconoAccion: Icons.insights_rounded,
                  onGenerar: () => _abrir(_Pantalla.cuentas),
                ),
                _TarjetaReporte(
                  icono: Icons.local_laundry_service_rounded,
                  titulo: 'Ropa pendiente',
                  descripcion:
                      'La ropa que ya pasó su fecha de entrega, la de hoy y '
                      'la de los próximos días, y las órdenes pagadas que '
                      'nadie ha venido a recoger.',
                  nota: 'Se ve en pantalla.',
                  accion: 'Ver la ropa',
                  iconoAccion: Icons.insights_rounded,
                  onGenerar: () => _abrir(_Pantalla.ropa),
                ),
                _TarjetaReporte(
                  icono: Icons.point_of_sale_rounded,
                  titulo: 'Reporte general de ventas',
                  descripcion:
                      'Cada orden del periodo con su total, lo pagado y lo '
                      'que falta. Después, el total cobrado, lo cobrado por '
                      'método de pago y contra lo pendiente, y el detalle de '
                      'cada pago.',
                  nota: 'Sale en PDF y, si lo pides, también en Excel.',
                  onGenerar: () =>
                      _abrirDialogo(context, const ReporteVentasDialog()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el diálogo de un reporte y, si se guardó, lo avisa.
  Future<void> _abrirDialogo(BuildContext context, Widget dialogo) async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (context) => dialogo,
    );

    if (mensaje == null || !context.mounted) return;

    await context.showSuccessDialog(mensaje);
  }
}

/// Las pantallas de estadísticas que se abren en lugar de las tarjetas.
enum _Pantalla { corte, cuentas, ropa }

/// Un reporte: qué es, qué trae y el botón para sacarlo.
class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.nota,
    this.accion = 'Generar reporte',
    this.iconoAccion = Icons.description_rounded,
    required this.onGenerar,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String nota;

  /// El texto del botón: un reporte se genera, el corte se ve.
  final String accion;
  final IconData iconoAccion;
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
                  icon: Icon(iconoAccion),
                  label: Text(accion),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
