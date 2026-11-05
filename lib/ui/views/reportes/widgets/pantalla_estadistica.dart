import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tarjeta_estadistica.dart';

/// El armazón de una pantalla de estadísticas: arriba la flecha para volver
/// a los reportes, el título, lo propio de la pantalla —[acciones]— y el
/// botón de actualizar; debajo, el contenido.
///
/// Se abre dentro de la sección de reportes, en lugar de las tarjetas.
class PantallaEstadistica extends StatelessWidget {
  const PantallaEstadistica({
    super.key,
    required this.titulo,
    required this.onVolver,
    required this.onRecargar,
    required this.cargando,
    required this.mensajeError,
    required this.contenido,
    this.acciones = const [],
  });

  final String titulo;
  final VoidCallback onVolver;
  final VoidCallback onRecargar;
  final bool cargando;
  final String mensajeError;

  /// En `null` mientras no hay nada que enseñar: la primera carga o una que
  /// falló.
  final Widget? contenido;

  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contenido = this.contenido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Volver a reportes',
                    onPressed: onVolver,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(titulo, style: theme.textTheme.headlineSmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  ...acciones,
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: onRecargar,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Reservado aunque no cargue: si apareciera y desapareciera, la
        // pantalla brincaría cada vez que se actualiza.
        SizedBox(
          height: 3,
          child: cargando ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: switch (contenido) {
            null when mensajeError.isNotEmpty => SinDatos(texto: mensajeError),
            null => const SizedBox.shrink(),
            final contenido => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: contenido,
            ),
          },
        ),
      ],
    );
  }
}
