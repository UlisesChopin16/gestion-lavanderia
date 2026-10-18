import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';

/// La igualdad es lo único que hay que comprobar aquí: de ella depende que una
/// relectura que devuelve lo mismo no vuelva a dibujar la pantalla.
void main() {
  test('dos listas con los mismos elementos son iguales', () {
    expect(const Filas([1, 2, 3]), const Filas([1, 2, 3]));
    expect(const Filas([1, 2, 3]).hashCode, const Filas([1, 2, 3]).hashCode);
  });

  test('el orden cuenta', () {
    expect(const Filas([1, 2, 3]), isNot(const Filas([3, 2, 1])));
  });

  test('se recorre y se cuenta como cualquier lista', () {
    const filas = Filas(['a', 'b']);

    expect(filas.length, 2);
    expect(filas.first, 'a');
    expect([...filas], ['a', 'b']);
    expect(const Filas<String>().isEmpty, isTrue);
  });
}
