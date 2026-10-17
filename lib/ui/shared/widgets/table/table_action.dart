import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Una acción sobre una fila: editar, eliminar, restaurar.
///
/// Una acción sin [onPressed] se muestra deshabilitada. Para que no aparezca,
/// no se incluye en la lista (`if (estaActivo) TableAction(...)`): así "no
/// disponible" y "no aplica" no se confunden en una sola bandera.
@immutable
class TableAction {
  const TableAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.color,
  });

  /// Qué hace la acción. Se usa como globo de ayuda del botón y como texto del
  /// menú, de modo que la versión compacta y la extendida nombran lo mismo.
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Color del botón. En `null` toma el primario del tema.
  final Color? color;

  bool get enabled => onPressed != null;
}

/// Los botones de acciones de una fila.
///
/// Con pocas acciones se muestran en línea; con [compact] o con más de
/// [maxInline] se agrupan en un menú, porque tres botones por fila dejan la
/// tabla sin ancho para los datos.
class TableActionsCell extends StatelessWidget {
  const TableActionsCell({
    super.key,
    required this.actions,
    this.compact = false,
    this.maxInline = 2,
  });

  final List<TableAction> actions;
  final bool compact;
  final int maxInline;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    if (compact || actions.length > maxInline) return _MenuActions(actions);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 4,
      children: [for (final action in actions) _ActionButton(action: action)],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final TableAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = action.color ?? scheme.primary;

    return IconButton.filled(
      icon: Icon(action.icon),
      tooltip: action.label,
      onPressed: action.onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: _foregroundOf(background),
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }

  /// Blanco o negro, el que contraste con el fondo del botón.
  ///
  /// Las acciones traen su color (rojo para eliminar, verde para restaurar) y
  /// no vienen del esquema del tema, así que no hay un `onColor` que usar.
  Color _foregroundOf(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

class _MenuActions extends StatelessWidget {
  const _MenuActions(this.actions);

  final List<TableAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TableAction>(
      tooltip: 'Menú de acciones',
      icon: const Icon(IconsManager.actionsMenu),
      iconColor: Theme.of(context).colorScheme.primary,
      // `onSelected` corre después de cerrar el menú, así que la acción no
      // puede usar un `context` ya desmontado.
      onSelected: (action) => action.onPressed?.call(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<TableAction>(
            value: action,
            enabled: action.enabled,
            child: Row(
              spacing: 10,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, color: action.color),
                Flexible(child: Text(action.label)),
              ],
            ),
          ),
      ],
    );
  }
}
