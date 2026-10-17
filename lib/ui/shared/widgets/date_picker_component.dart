import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/delete_button.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Campo de sólo lectura que abre un calendario para elegir una fecha.
///
/// El texto se arma a partir de [currentDate] en `initState` y en
/// `didUpdateWidget`, no dentro de `build`: escribir en el controlador durante
/// la construcción vuelve a notificar a sus escuchas en medio del dibujado.
class DatePickerComponent extends StatefulWidget {
  const DatePickerComponent({
    super.key,
    required this.changeDate,
    this.currentDate,
    this.firstDate,
    this.lastDate,
    this.onDelete,
    this.width,
    this.labelText,
    this.showTodayButton = false,
  });

  final DateTime? currentDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> changeDate;

  /// Si se pasa, el campo muestra un botón para quitar la fecha elegida.
  final VoidCallback? onDelete;

  final double? width;
  final String? labelText;

  /// Agrega un atajo para elegir hoy dentro del calendario.
  final bool showTodayButton;

  @override
  State<DatePickerComponent> createState() => _DatePickerComponentState();
}

class _DatePickerComponentState extends State<DatePickerComponent> {
  late final TextEditingController _controller = TextEditingController(
    text: _text,
  );

  String get _text => widget.currentDate?.formatDate ?? '';

  @override
  void didUpdateWidget(DatePickerComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDate != widget.currentDate) _controller.text = _text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget get _prefix {
    final onDelete = widget.onDelete;
    if (onDelete != null && widget.currentDate != null) {
      return DeleteButton(onPressed: onDelete, tooltip: 'Quitar la fecha');
    }
    return const Icon(IconsManager.calendar);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: true,
      canRequestFocus: false,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Selecciona una fecha',
        constraints: BoxConstraints(
          maxHeight: 40,
          maxWidth: widget.width ?? 160,
        ),
        prefixIcon: _prefix,
      ),
      onTap: _openCalendar,
    );
  }

  Future<void> _openCalendar() async {
    final (initialDate, firstDate, lastDate) = _calculateDates();

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        showTodayButton: widget.showTodayButton,
      ),
    );

    // Un diálogo cerrado sin elegir devuelve null, y eso no es "sin fecha":
    // la fecha anterior se queda como estaba.
    if (selected != null) widget.changeDate(selected);
  }

  /// La fecha inicial y los límites que el calendario puede mostrar.
  ///
  /// Los extremos se ordenan entre sí y la fecha inicial se recorta a ellos,
  /// porque el calendario lanza una excepción si recibe un rango invertido o
  /// una fecha fuera de rango.
  (DateTime initialDate, DateTime firstDate, DateTime lastDate)
  _calculateDates() {
    var firstDate = widget.firstDate ?? DateTime(2000);
    var lastDate = widget.lastDate ?? DateTime.now();

    if (lastDate.isBefore(firstDate)) {
      (firstDate, lastDate) = (lastDate, firstDate);
    }

    final initialDate = (widget.currentDate ?? DateTime.now()).clampDate(
      firstDate,
      lastDate,
    );

    return (initialDate, firstDate, lastDate);
  }
}

/// El calendario. Se cierra devolviendo la fecha elegida, o nada si se cancela.
class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.showTodayButton,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool showTodayButton;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _selected = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: const _Header(),
      content: SizedBox(
        width: 300,
        height: 300,
        child: CalendarDatePicker(
          initialDate: widget.initialDate,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (date) => setState(() => _selected = date),
        ),
      ),
      actions: [
        if (widget.showTodayButton)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(DateTime.now().clampDate(widget.firstDate, widget.lastDate)),
            child: const Text('Hoy'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(
            'Aceptar',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(15),
        color: background,
        child: Row(
          spacing: 5,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Selecciona una fecha',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: foreground,
                ),
              ),
            ),
            Icon(Icons.calendar_month, size: 30, color: foreground),
          ],
        ),
      ),
    );
  }
}
