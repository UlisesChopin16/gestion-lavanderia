/// Error de una regla de la base de datos (duplicados, categoría inactiva,
/// escrituras que no se aplicaron). El `message` está redactado para mostrarse
/// al usuario tal cual.
class SQLException implements Exception {
  final String message;

  const SQLException({required this.message});

  @override
  String toString() => 'SQLException: $message';
}
