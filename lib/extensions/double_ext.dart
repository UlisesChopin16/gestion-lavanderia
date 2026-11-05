extension DoubleExt on double {
  /// `$1,250.00`: con signo y separador de miles, como en un recibo.
  ///
  /// Lo comparten el ticket y los reportes: un importe se escribe igual en
  /// todo lo que sale de la aplicación.
  String get enPesos {
    final partes = abs().toStringAsFixed(2).split('.');
    final enteros = partes.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final signo = this < -0.005 ? '-' : '';

    return '$signo\$$enteros.${partes.last}';
  }
}
