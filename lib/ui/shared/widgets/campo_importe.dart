import 'package:flutter/material.dart';

/// Un campo de importe que se mantiene a la par de su número.
///
/// El número lo gobierna quien lo usa —lo recorta al saldo, lo pone un
/// atajo—, así que el campo repone su texto cuando el número cambia por
/// fuera, y no lo toca cuando el cambio vino de lo que se está tecleando,
/// para no mover el cursor a media captura.
///
/// Nace vacío con la pista `0.00` en lugar de con un `0.00` escrito: un cero
/// escrito parece un importe capturado, y hay que borrarlo antes de teclear el
/// de verdad.
class CampoImporte extends StatefulWidget {
  const CampoImporte({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onCambio,
    this.ayuda,
    this.error,
    this.sufijo,
  });

  final String etiqueta;
  final double valor;
  final ValueChanged<double> onCambio;

  /// El texto de debajo. Ocupa un renglón más de alto: en una fila de
  /// controles del mismo alto no se usa.
  final String? ayuda;
  final String? error;

  final Widget? sufijo;

  @override
  State<CampoImporte> createState() => _CampoImporteState();
}

class _CampoImporteState extends State<CampoImporte> {
  late final TextEditingController _controller = TextEditingController(
    text: _texto,
  );

  String get _texto =>
      widget.valor == 0 ? '' : widget.valor.toStringAsFixed(2);

  @override
  void didUpdateWidget(CampoImporte oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se compara el número y no el texto, y el campo vacío cuenta como cero:
    // "50" y "50.00" son el mismo importe, y borrar el campo del todo no tiene
    // por qué hacer que se reponga solo.
    final escrito = double.tryParse(_controller.text) ?? 0;
    if (escrito != widget.valor) _controller.text = _texto;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        hintText: '0.00',
        // La etiqueta se queda arriba aunque el campo esté vacío: si bajara a
        // ocupar su hueco, la pista no llegaría a verse.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: widget.ayuda,
        errorText: widget.error,
        suffixIcon: widget.sufijo,
      ),
      onChanged: (texto) => widget.onCambio(double.tryParse(texto) ?? 0),
    );
  }
}
