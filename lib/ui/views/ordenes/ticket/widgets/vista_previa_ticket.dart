import 'dart:typed_data';

import 'package:flutter/material.dart';

/// El ticket como se va a ver, sobre un fondo que lo hace parecer papel.
///
/// Las imágenes son el PDF ya rasterizado, no un dibujo aparte del ticket: lo
/// que aquí se ve es exactamente lo que se descarga y lo que recibe el
/// cliente.
class VistaPreviaTicket extends StatelessWidget {
  const VistaPreviaTicket({
    super.key,
    required this.paginas,
    required this.cargando,
  });

  final List<Uint8List> paginas;
  final bool cargando;

  /// El ancho al que se enseña el rollo: algo más que sus 80 mm reales en
  /// pantalla (unos 300 px), para que el texto chico del ticket se lea sin
  /// acercarse.
  static const double anchoPapel = 360;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: switch (paginas) {
        _ when cargando => const _Generando(),
        [] => const _SinVistaPrevia(),
        final paginas => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(
            child: Column(
              spacing: 16,
              children: [for (final pagina in paginas) _Papel(imagen: pagina)],
            ),
          ),
        ),
      },
    );
  }
}

/// Una página del ticket, con la sombra de una hoja sobre la mesa.
class _Papel extends StatelessWidget {
  const _Papel({required this.imagen});

  final Uint8List imagen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: VistaPreviaTicket.anchoPapel,
      decoration: BoxDecoration(
        // Blanco en los dos temas: es papel, no una superficie de la app.
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Image.memory(
        imagen,
        width: VistaPreviaTicket.anchoPapel,
        fit: BoxFit.fitWidth,
        filterQuality: FilterQuality.medium,
        // Para los lectores de pantalla: la imagen es todo el ticket.
        semanticLabel: 'Vista previa del ticket',
      ),
    );
  }
}

/// Con alto propio: el diálogo mide lo que trae, y un indicador solo lo
/// dejaría del tamaño de un botón.
class _Generando extends StatelessWidget {
  const _Generando();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const CircularProgressIndicator(),
            Text('Generando el ticket…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Cuando no hay imágenes que enseñar. El porqué va en el aviso de arriba.
class _SinVistaPrevia extends StatelessWidget {
  const _SinVistaPrevia();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            Text('Sin vista previa', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
