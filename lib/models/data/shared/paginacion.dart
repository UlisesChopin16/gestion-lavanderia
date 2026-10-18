import 'package:flutter/foundation.dart' show immutable;

/// La porción de un listado que se está viendo.
///
/// El recorte se hace en memoria, sobre la lista que ya devolvió la base, y no
/// con `LIMIT`/`OFFSET`: la base es local y un catálogo de lavandería se mide
/// en cientos de filas, así que leerlo entero cuesta menos que una consulta por
/// página más otra para contar el total. Si algún listado llegara a crecer de
/// verdad, lo que cambia es el datasource; esta clase y la interfaz siguen
/// igual, porque sólo hablan de página, tamaño y total.
///
/// La página es de base 1 —"página 1 de 4" es lo que se lee en pantalla— y
/// nunca se sale del rango: todos los cambios pasan por los métodos de abajo,
/// que la recortan contra el total vigente.
@immutable
class Paginacion {
  const Paginacion({
    this.pagina = 1,
    this.porPagina = porPaginaPorOmision,
    this.total = 0,
  });

  /// La página que se está viendo, empezando en 1.
  final int pagina;

  /// Cuántas filas caben en una página.
  final int porPagina;

  /// Cuántas filas tiene el listado completo, ya filtrado.
  final int total;

  static const int porPaginaPorOmision = 10;

  /// Los tamaños de página que se ofrecen en el pie de la tabla.
  static const List<int> opciones = [10, 25, 50, 100];

  /// Cuántas páginas hay. Un listado vacío tiene una página, vacía: así el pie
  /// dice "página 1 de 1" en lugar de "1 de 0".
  int get paginas => total <= 0 ? 1 : ((total - 1) ~/ porPagina) + 1;

  /// El número de la primera fila de la página, para el "mostrando 11-20".
  int get desde => total == 0 ? 0 : (pagina - 1) * porPagina + 1;

  /// El número de la última fila de la página.
  int get hasta {
    final fin = pagina * porPagina;
    return fin < total ? fin : total;
  }

  bool get hayAnterior => pagina > 1;

  bool get haySiguiente => pagina < paginas;

  /// Las filas de [todas] que caen en esta página.
  List<T> recortar<T>(Iterable<T> todas) {
    return todas.skip((pagina - 1) * porPagina).take(porPagina).toList();
  }

  /// La misma paginación en otra página, sin salirse del rango.
  Paginacion conPagina(int pagina) => _con(pagina: pagina);

  /// Otro tamaño de página, conservando a la vista la primera fila de la
  /// página actual: cambiar de 10 a 25 filas estando en la página 3 deja
  /// arriba la fila 21, y no la 1 como haría volver al principio.
  Paginacion conPorPagina(int porPagina) {
    if (porPagina <= 0) return this;

    final primera = (pagina - 1) * this.porPagina;

    return _con(pagina: primera ~/ porPagina + 1, porPagina: porPagina);
  }

  /// El mismo tamaño de página sobre un listado de otro tamaño.
  ///
  /// Es lo que se aplica después de cada lectura: si al dar de baja el último
  /// renglón la página deja de existir, se cae a la última que sí existe en
  /// lugar de mostrar una página vacía.
  Paginacion conTotal(int total) => _con(total: total);

  /// De vuelta a la primera página, que es donde hay que mirar después de
  /// cambiar un filtro: lo que se busca rara vez está en la página 7 de lo
  /// anterior.
  Paginacion primera() => _con(pagina: 1);

  Paginacion _con({int? pagina, int? porPagina, int? total}) {
    final nueva = Paginacion(
      pagina: 1,
      porPagina: porPagina ?? this.porPagina,
      total: total ?? this.total,
    );

    final pedida = pagina ?? this.pagina;
    final acotada = pedida.clamp(1, nueva.paginas);

    return Paginacion(
      pagina: acotada,
      porPagina: nueva.porPagina,
      total: nueva.total,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Paginacion &&
      other.pagina == pagina &&
      other.porPagina == porPagina &&
      other.total == total;

  @override
  int get hashCode => Object.hash(pagina, porPagina, total);

  @override
  String toString() =>
      'Paginacion(pagina: $pagina, porPagina: $porPagina, total: $total)';
}
