/// Qué hacer cuando una operación falla: recibe el error original y el mensaje
/// ya traducido para el usuario.
typedef AsyncCallbackError = Future<void> Function(
  Object error,
  String message,
);

/// Cambio de valor que además dice en qué posición de una lista ocurrió.
typedef IndexValueChange<T> = void Function(int index, T value);
