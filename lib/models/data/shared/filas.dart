import 'package:flutter/foundation.dart' show immutable, listEquals;

/// Una lista de resultados dentro del estado de una pantalla.
///
/// Envuelve la lista en lugar de dejarla suelta por la misma razón por la que
/// `ErroresEmpresa` envuelve su mapa: la versión instalada de freezed (3.2.3)
/// genera código inválido para un campo `List` —le pone `final` a un parámetro
/// con nombre, que Dart 3.13 ya no acepta—. El estado declara `Filas<T>` y
/// freezed la trata como cualquier otro valor.
///
/// Es un `Iterable`, así que se recorre, se cuenta y se pregunta si está vacía
/// como cualquier lista; lo que no se puede es modificarla, que es justo lo
/// que se quiere de algo guardado en un estado inmutable.
@immutable
class Filas<T> extends Iterable<T> {
  const Filas([this._items = const []]);

  final List<T> _items;

  @override
  Iterator<T> get iterator => _items.iterator;

  /// Una copia modificable, para quien necesite una `List` de verdad.
  @override
  List<T> toList({bool growable = true}) =>
      List<T>.of(_items, growable: growable);

  /// Dos listas con los mismos elementos en el mismo orden son iguales: así
  /// una relectura que devuelve lo mismo no redibuja la pantalla.
  @override
  bool operator ==(Object other) =>
      other is Filas<T> && listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);
}
