import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/types/range_dates_types.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/base_dialog.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/delete_button.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Campo de sólo lectura que abre un calendario para elegir un rango.
///
/// Devuelve la lista tal como la entrega el calendario: vacía cuando no hay
/// nada elegido, con una fecha mientras el rango está a medias y con dos
/// cuando está completo. Los filtros ya saben leerla así, y recortarla aquí
/// escondería el rango incompleto que el usuario está armando.
class DateRangePicker extends StatefulWidget {
  const DateRangePicker({
    super.key,
    this.selectedDates = const [],
    this.changeDate,
    this.onDelete,
    this.firstDate,
    this.lastDate,
    this.width,
    this.labelText,
    this.showDelete,
  });

  final List<DateTime?> selectedDates;
  final ValueChanged<List<DateTime?>>? changeDate;
  final VoidCallback? onDelete;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double? width;
  final String? labelText;

  /// En `null` el botón de quitar aparece cuando hay fechas elegidas.
  final bool? showDelete;

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  late final TextEditingController _controller = TextEditingController(
    text: _text,
  );

  String get _text =>
      widget.selectedDates.map((date) => date.formatDate).join(' - ');

  @override
  void didUpdateWidget(DateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _text;
    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget get _prefix {
    final showDelete = widget.showDelete ?? widget.selectedDates.isNotEmpty;

    if (showDelete) {
      return DeleteButton(
        onPressed: widget.onDelete,
        tooltip: 'Quitar las fechas',
      );
    }

    return const Icon(IconsManager.calendarRange);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: true,
      canRequestFocus: false,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Selecciona las fechas',
        hintText: '01/ene/2026 - 31/ene/2026',
        constraints: BoxConstraints(
          maxHeight: 40,
          maxWidth: widget.width ?? 230,
        ),
        prefixIcon: _prefix,
      ),
      onTap: _openCalendar,
    );
  }

  Future<void> _openCalendar() async {
    final (firstDate, lastDate) = _calculateDates();

    // El rango viaja por el callback y no como resultado del diálogo: cerrarlo
    // es asunto de [BaseDialog], y dos cierres encadenados sacarían también a
    // la pantalla que está debajo.
    await showDialog<bool>(
      context: context,
      builder: (context) => _RangeDialog(
        firstDate: firstDate,
        lastDate: lastDate,
        selectedDates: widget.selectedDates,
        onAccept: (dates) => widget.changeDate?.call(dates),
      ),
    );
  }

  /// Los límites que el calendario puede mostrar, ya ordenados entre sí.
  (DateTime firstDate, DateTime lastDate) _calculateDates() {
    var firstDate = widget.firstDate ?? DateTime(2000);
    var lastDate = widget.lastDate ?? DateTime.now();

    if (lastDate.isBefore(firstDate)) {
      (firstDate, lastDate) = (lastDate, firstDate);
    }

    return (firstDate, lastDate);
  }
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.selectedDates,
    required this.onAccept,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final List<DateTime?> selectedDates;
  final ValueChanged<List<DateTime?>> onAccept;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late List<DateTime?> _selected = widget.selectedDates;

  /// Qué atajo está aplicado, para resaltarlo. Se olvida en cuanto se toca el
  /// calendario, porque entonces el rango ya no es el del atajo.
  RangeDatesTypes? _shortcut;

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: 'Selecciona las fechas',
      onActionPressed: () => widget.onAccept(_selected),
      content: SizedBox(
        width: 325,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            CalendarDatePicker2(
              value: _selected,
              config: CalendarDatePicker2Config(
                calendarType: CalendarDatePicker2Type.range,
                rangeBidirectional: true,
                allowSameValueSelection: true,
                centerAlignModePicker: true,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                selectedDayHighlightColor: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              onValueChanged: (dates) => setState(() {
                _selected = dates;
                _shortcut = null;
              }),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final range in RangeDatesTypes.values)
                  _ShortcutButton(
                    text: range.title,
                    isSelected: _shortcut == range,
                    onPressed: () => setState(() {
                      _selected = range.range();
                      _shortcut = range;
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.text,
    required this.isSelected,
    required this.onPressed,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: isSelected
          ? TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      child: Text(text),
    );
  }
}
