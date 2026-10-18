import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

/// El color de la marca, con el que se arma el tema de la aplicación.
///
/// Son muestras de color y no un grupo de `Radio` pintado con cada color: el
/// punto de un radio amarillo sobre fondo claro casi no se ve, y aquí el color
/// elegido se marca con una paloma que contrasta con el fondo que tiene debajo.
class PaletaColores extends ConsumerWidget {
  const PaletaColores({super.key, required this.ancho});

  final double ancho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final (seleccionado, editable) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (estado.empresa.color, estado.editable),
      ),
    );

    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Color de la empresa',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (indice, color) in ColoresEmpresa.values.indexed)
                _Muestra(
                  color: color,
                  numero: indice + 1,
                  seleccionado: color == seleccionado,
                  onPressed: editable
                      ? () => notifier.cambiarColor(color)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Muestra extends StatelessWidget {
  const _Muestra({
    required this.color,
    required this.numero,
    required this.seleccionado,
    this.onPressed,
  });

  final Color color;

  /// Para nombrar la muestra en el lector de pantalla: un color no se puede
  /// describir con el color mismo.
  final int numero;
  final bool seleccionado;
  final VoidCallback? onPressed;

  static const _lado = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contraste =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Semantics(
      button: true,
      selected: seleccionado,
      label: 'Color $numero',
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            height: _lado,
            width: _lado,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: seleccionado ? scheme.onSurface : scheme.outlineVariant,
                width: seleccionado ? 3 : 1,
              ),
            ),
            child: seleccionado
                ? Icon(Icons.check_rounded, size: 20, color: contraste)
                : null,
          ),
        ),
      ),
    );
  }
}
