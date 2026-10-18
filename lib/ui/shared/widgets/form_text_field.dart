import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto de un formulario cuyo valor vive en el estado.
///
/// Administra su propio controlador y lo vuelve a sincronizar cuando [value]
/// cambia desde fuera. Los formularios anteriores usaban
/// `TextFormField(initialValue: ...)`, y ese parámetro sólo se lee en la
/// primera construcción: el campo se quedaba vacío si los datos llegaban de la
/// base después de dibujar la pantalla, y tampoco volvía a su valor al
/// cancelar la edición.
class FormTextField extends StatefulWidget {
  const FormTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
    this.width,
    this.onSubmitted,
  });

  /// El valor que el campo debe mostrar.
  final String value;
  final ValueChanged<String> onChanged;

  final String label;
  final String? hint;
  final IconData? icon;
  final Widget? suffix;

  /// El motivo por el que el valor no sirve. En `null` el campo se ve normal.
  final String? errorText;

  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Ancho máximo del campo, para alinearlo con los demás del formulario.
  final double? width;

  final ValueChanged<String>? onSubmitted;

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(FormTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sólo cuando el valor de fuera y el texto del campo discrepan: escribir en
    // el controlador en cada reconstrucción movería el cursor al final a media
    // captura.
    if (_controller.text != widget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final width = widget.width;

    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: widget.suffix,
        constraints: width == null ? null : BoxConstraints(maxWidth: width),
      ),
    );
  }
}
