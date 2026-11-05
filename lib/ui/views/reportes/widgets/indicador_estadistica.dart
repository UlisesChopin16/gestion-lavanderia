import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/historial/widgets/colores_historial.dart';

/// Los indicadores de una pantalla de estadísticas, arriba de las gráficas:
/// cuatro por renglón en una ventana ancha y dos en una angosta.
///
/// Son números sueltos, y un número suelto se lee mejor escrito que en una
/// gráfica de una sola barra.
class FilaIndicadores extends StatelessWidget {
  const FilaIndicadores({super.key, required this.indicadores});

  final List<Widget> indicadores;

  /// Por debajo de este ancho van dos por renglón.
  static const double _corteCuatro = 900;

  static const double _espacio = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final porRenglon = constraints.maxWidth >= _corteCuatro ? 4 : 2;
        final ancho =
            (constraints.maxWidth - _espacio * (porRenglon - 1)) / porRenglon;

        return Wrap(
          spacing: _espacio,
          runSpacing: _espacio,
          children: [
            for (final indicador in indicadores)
              SizedBox(width: ancho, child: indicador),
          ],
        );
      },
    );
  }
}

/// Una cifra con su título y un renglón al pie que la explica.
class IndicadorEstadistica extends StatelessWidget {
  const IndicadorEstadistica({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.pie,
    this.principal = false,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final Widget pie;

  /// La cifra por la que se abre la pantalla: va más grande y sobre el color
  /// de la empresa. Una por pantalla.
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borde = scheme.bordeTarjeta;
    final tenue = principal
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: principal ? scheme.primaryContainer : scheme.fondoTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: principal || borde == null ? null : Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(icono, size: 18, color: tenue),
              Expanded(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: tenue),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style:
                  (principal
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: principal ? scheme.onPrimaryContainer : null,
                      ),
            ),
          ),
          DefaultTextStyle.merge(
            style: TextStyle(color: tenue),
            child: pie,
          ),
        ],
      ),
    );
  }
}

/// El renglón chico al pie de un indicador.
class NotaIndicador extends StatelessWidget {
  const NotaIndicador(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: DefaultTextStyle.of(context).style.color),
    );
  }
}
