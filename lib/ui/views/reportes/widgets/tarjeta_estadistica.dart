import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/colores_historial.dart';

/// El recuadro de cada parte de una pantalla de estadísticas: un título que
/// dice qué se mide, una nota opcional debajo y el contenido.
///
/// Lleva los mismos fondos que las tarjetas del historial, que ya resolvieron
/// cómo se despega una tarjeta en claro y en oscuro.
class TarjetaEstadistica extends StatelessWidget {
  const TarjetaEstadistica({
    super.key,
    required this.titulo,
    this.nota,
    required this.child,
  });

  final String titulo;
  final String? nota;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borde = scheme.bordeTarjeta;
    final nota = this.nota;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: scheme.fondoTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: theme.textTheme.titleMedium),
          if (nota != null)
            Text(
              nota,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Lo que va en lugar de una gráfica que no tiene nada que enseñar.
class SinDatos extends StatelessWidget {
  const SinDatos({super.key, required this.texto, this.alto = 120});

  final String texto;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: alto,
      child: Center(
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
