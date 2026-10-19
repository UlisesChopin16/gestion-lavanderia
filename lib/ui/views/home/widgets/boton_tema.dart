import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/theme_mode_ext.dart';

/// Cambia el tema de la aplicación: un toque y se pasa de claro a oscuro, o
/// al revés.
///
/// El icono y el globo de ayuda dicen el modo que está puesto, no el que
/// vendría al pulsarlo. Antes de tocarlo la primera vez ese modo puede ser
/// "según el sistema", con el que arranca la aplicación; de ahí se sale al
/// contrario de lo que se esté viendo y ya no se vuelve.
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
