import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/extensions/string_ext.dart';

/// Un nombre escrito de corrido, repartido en nombres y apellidos.
///
/// Sirve para llenar un formulario con lo que alguien ya tecleó en un
/// buscador: nadie debería escribir "Ulises Shie Sotelo Chopin" dos veces,
/// una para buscarlo y otra para darlo de alta.
///
/// El reparto es una conjetura, no una certeza: "Ana María López" puede ser
/// una Ana María López o una Ana María-López, y no hay forma de saberlo desde
/// el texto. Por eso esto sólo precarga un formulario que se puede corregir, y
/// nunca decide por su cuenta lo que se guarda.
@immutable
class NombreCompleto {
  const NombreCompleto({required this.nombres, required this.apellidos});

  /// Reparte [texto] con la costumbre de aquí: el apellido paterno y el
  /// materno al final, y lo que sobre al principio son nombres de pila.
  ///
  /// Según cuántas palabras traiga:
  ///
  /// - una, es un nombre suelto: "Juan";
  /// - dos, un nombre y un apellido: "Juan Pérez";
  /// - tres, un nombre y los dos apellidos: "Juan Pérez López", que es el
  ///   caso más común y el que decide la ambigüedad de "Ana María López";
  /// - cuatro o más, dos nombres y el resto apellidos: "Ulises Shie Sotelo
  ///   Chopin".
  ///
  /// Las partículas no cuentan como palabra propia: van pegadas a la que
  /// siguen, de modo que "María de los Ángeles López Cruz" se reparte en
  /// "María de los Ángeles" y "López Cruz" y no en mitades a ciegas.
  factory NombreCompleto.repartir(String texto) {
    final partes = _agrupar(texto.normalizeSpaces());

    return switch (partes.length) {
      0 => const NombreCompleto(nombres: '', apellidos: ''),
      1 => NombreCompleto(nombres: partes.first, apellidos: ''),
      2 => NombreCompleto(nombres: partes.first, apellidos: partes.last),
      3 => NombreCompleto(
        nombres: partes.first,
        apellidos: partes.skip(1).join(' '),
      ),
      _ => NombreCompleto(
        nombres: partes.take(2).join(' '),
        apellidos: partes.skip(2).join(' '),
      ),
    };
  }

  final String nombres;
  final String apellidos;

  /// Lo que no es un nombre por sí solo, sino el principio de uno: "de la
  /// Cruz" es un apellido, no tres.
  static const _particulas = {
    'da',
    'das',
    'de',
    'del',
    'der',
    'di',
    'do',
    'dos',
    'e',
    'la',
    'las',
    'los',
    'san',
    'santa',
    'van',
    'von',
    'y',
  };

  /// Las palabras de [texto] con las partículas pegadas a la que las sigue.
  static List<String> _agrupar(String texto) {
    if (texto.isEmpty) return const [];

    final grupos = <String>[];
    final pendiente = <String>[];

    for (final palabra in texto.split(' ')) {
      pendiente.add(palabra);

      // Una partícula se queda esperando a la palabra que encabeza.
      if (_particulas.contains(palabra.toLowerCase())) continue;

      grupos.add(pendiente.join(' '));
      pendiente.clear();
    }

    // Una partícula al final no encabeza nada —"Juan de"—, así que se queda
    // con el grupo anterior en lugar de perderse.
    if (pendiente.isEmpty) return grupos;

    if (grupos.isEmpty) return [pendiente.join(' ')];

    grupos[grupos.length - 1] = '${grupos.last} ${pendiente.join(' ')}';

    return grupos;
  }

  @override
  bool operator ==(Object other) =>
      other is NombreCompleto &&
      other.nombres == nombres &&
      other.apellidos == apellidos;

  @override
  int get hashCode => Object.hash(nombres, apellidos);

  @override
  String toString() =>
      'NombreCompleto(nombres: $nombres, apellidos: $apellidos)';
}
