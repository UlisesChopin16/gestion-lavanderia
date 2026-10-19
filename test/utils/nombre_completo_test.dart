import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/utils/nombre_completo.dart';

/// Comprueba cómo se reparte un nombre escrito de corrido, que es lo que
/// precarga el formulario de un cliente nuevo desde lo que se tecleó al
/// buscarlo.
void main() {
  NombreCompleto repartir(String texto) => NombreCompleto.repartir(texto);

  test('sin texto no hay nada que repartir', () {
    expect(repartir(''), const NombreCompleto(nombres: '', apellidos: ''));
    expect(repartir('   '), const NombreCompleto(nombres: '', apellidos: ''));
  });

  test('una palabra es un nombre de pila suelto', () {
    expect(
      repartir('Juan'),
      const NombreCompleto(nombres: 'Juan', apellidos: ''),
    );
  });

  test('dos palabras son un nombre y un apellido', () {
    expect(
      repartir('Juan Pérez'),
      const NombreCompleto(nombres: 'Juan', apellidos: 'Pérez'),
    );
  });

  test('tres palabras son un nombre y los dos apellidos', () {
    // El caso ambiguo: "Ana María López" podría ser una Ana María, pero un
    // nombre con los dos apellidos es lo común y es lo que se supone.
    expect(
      repartir('Juan Pérez López'),
      const NombreCompleto(nombres: 'Juan', apellidos: 'Pérez López'),
    );
  });

  test('cuatro palabras son dos nombres y dos apellidos', () {
    expect(
      repartir('Ulises Shie Sotelo Chopin'),
      const NombreCompleto(nombres: 'Ulises Shie', apellidos: 'Sotelo Chopin'),
    );
  });

  group('las partículas no cuentan como palabra propia', () {
    test('un nombre compuesto con partículas sigue siendo el nombre', () {
      expect(
        repartir('María de los Ángeles López Cruz'),
        const NombreCompleto(
          nombres: 'María de los Ángeles',
          apellidos: 'López Cruz',
        ),
      );
    });

    test('un apellido con partículas sigue siendo un apellido', () {
      expect(
        repartir('Juan Carlos Pérez de la Cruz'),
        const NombreCompleto(
          nombres: 'Juan Carlos',
          apellidos: 'Pérez de la Cruz',
        ),
      );
    });

    test('una partícula al final se queda con lo que la precede', () {
      expect(
        repartir('Juan de'),
        const NombreCompleto(nombres: 'Juan de', apellidos: ''),
      );
    });
  });

  test('los espacios de más no cambian el reparto', () {
    expect(
      repartir('  Juan   Pérez  López '),
      const NombreCompleto(nombres: 'Juan', apellidos: 'Pérez López'),
    );
  });

  test('más de cuatro palabras dejan dos nombres y el resto apellidos', () {
    expect(
      repartir('Ana Sofía Pérez López Cruz'),
      const NombreCompleto(nombres: 'Ana Sofía', apellidos: 'Pérez López Cruz'),
    );
  });
}
