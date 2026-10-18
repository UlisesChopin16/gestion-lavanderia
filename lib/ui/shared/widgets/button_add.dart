import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Da de alta un registro del listado.
///
/// Va en el encabezado y no entre los filtros porque no acota la lista, la
/// hace crecer: puesto junto a ellos parecía uno más.
///
/// Es el botón lleno de la pantalla —el color primario, el de la acción
/// principal—, así que no hay dos compitiendo por serlo: el de limpiar los
/// filtros va en tono apagado a propósito.
class ButtonAdd extends StatelessWidget {
  const ButtonAdd({super.key, required this.label, this.onPressed});

  final String label;

  /// En `null` el botón se ve deshabilitado, que es lo que corresponde cuando
  /// todavía no se puede dar de alta nada.
  final VoidCallback? onPressed;

  /// El mismo redondeo que los demás recuadros de la tarjeta.
  static const double radio = 16;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(IconsManager.add),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
    );
  }
}
