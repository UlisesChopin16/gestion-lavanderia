import 'package:flutter/material.dart';

/// Una opción de [FiltroEtiquetas]: su valor y cómo se lee, con cuántos
/// renglones deja ver.
typedef OpcionFiltro<T> = ({T valor, String titulo, int cuantos});

/// Las opciones para acotar una lista, como etiquetas: se ven todas, cada
/// una dice cuántos renglones deja, y se elige con un toque.
class FiltroEtiquetas<T> extends StatelessWidget {
  const FiltroEtiquetas({
    super.key,
    required this.opciones,
    required this.elegida,
    required this.onElegir,
  });

  final List<OpcionFiltro<T>> opciones;
  final T elegida;
  final ValueChanged<T> onElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (:valor, :titulo, :cuantos) in opciones)
          ChoiceChip(
            label: Text('$titulo ($cuantos)'),
            selected: valor == elegida,
            onSelected: (_) => onElegir(valor),
          ),
      ],
    );
  }
}
