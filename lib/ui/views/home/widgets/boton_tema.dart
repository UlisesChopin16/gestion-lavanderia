import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/theme_mode_ext.dart';

/// Cambia el tema de la aplicación.
///
/// Es un botón que avanza entre los tres modos y no el interruptor de antes,
/// que sólo alternaba claro y oscuro: con un interruptor no hay forma de
/// volver a "según el sistema", que además es con el que arranca.
///
/// El icono y el globo de ayuda dicen el modo que está puesto, no el que
/// vendría al pulsarlo.
class BotonTema extends StatelessWidget {
  const BotonTema({
    super.key,
    required this.themeMode,
    required this.onPressed,
  });

  final ThemeMode themeMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(themeMode.icon),
      tooltip: 'Tema: ${themeMode.title}',
    );
  }
}
