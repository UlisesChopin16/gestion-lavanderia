import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/shared/paginacion.dart';

/// Comprueba el recorte de las páginas y, sobre todo, que la página nunca se
/// salga del rango: es lo que decide si un listado se ve o se queda en blanco
/// después de filtrar o de dar de baja un renglón.
void main() {
  final treintaYSiete = List.generate(37, (indice) => indice + 1);

  group('el recorte', () {
    test('la primera página trae las primeras filas', () {
      const paginacion = Paginacion(porPagina: 10, total: 37);

      expect(paginacion.recortar(treintaYSiete), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(paginacion.desde, 1);
      expect(paginacion.hasta, 10);
    });

    test('la última página trae sólo lo que queda', () {
      const paginacion = Paginacion(pagina: 4, porPagina: 10, total: 37);

      expect(paginacion.recortar(treintaYSiete), [31, 32, 33, 34, 35, 36, 37]);
      expect(paginacion.desde, 31);
      expect(paginacion.hasta, 37);
    });

    test('un listado vacío tiene una página, vacía', () {
      const paginacion = Paginacion();

      expect(paginacion.recortar(<int>[]), isEmpty);
      expect(paginacion.paginas, 1);
      expect(paginacion.desde, 0);
      expect(paginacion.hasta, 0);
      expect(paginacion.hayAnterior, isFalse);
      expect(paginacion.haySiguiente, isFalse);
    });
  });

  group('al cambiar de página', () {
    test('no se pasa de la última', () {
      const paginacion = Paginacion(porPagina: 10, total: 37);

      expect(paginacion.conPagina(9).pagina, 4);
    });

    test('no se baja de la primera', () {
      const paginacion = Paginacion(pagina: 3, porPagina: 10, total: 37);

      expect(paginacion.conPagina(0).pagina, 1);
    });
  });

  group('al cambiar el tamaño de página', () {
    test('con páginas más chicas se sigue arriba de la misma fila', () {
      // Página 3 de 10 en 10: arriba está la fila 21. De 5 en 5, esa fila
      // encabeza la página 5.
      const paginacion = Paginacion(pagina: 3, porPagina: 10, total: 100);

      final nueva = paginacion.conPorPagina(5);

      expect(nueva.porPagina, 5);
      expect(nueva.pagina, 5);
      expect(nueva.desde, 21);
    });

    test('con páginas más grandes esa fila sigue a la vista', () {
      // La fila 21 cabe en la primera página de 25.
      const paginacion = Paginacion(pagina: 3, porPagina: 10, total: 100);

      final nueva = paginacion.conPorPagina(25);

      expect(nueva.pagina, 1);
      expect(nueva.hasta, 25);
    });

    test('un tamaño inválido no cambia nada', () {
      const paginacion = Paginacion(porPagina: 10, total: 37);

      expect(paginacion.conPorPagina(0), paginacion);
    });
  });

  group('al cambiar el total', () {
    test('la página se recorta cuando el listado encoge', () {
      const paginacion = Paginacion(pagina: 4, porPagina: 10, total: 37);

      // Se dieron de baja las filas de la última página.
      expect(paginacion.conTotal(30).pagina, 3);
    });

    test('la página se conserva cuando sigue existiendo', () {
      const paginacion = Paginacion(pagina: 2, porPagina: 10, total: 37);

      expect(paginacion.conTotal(35).pagina, 2);
    });

    test('un listado que se vacía deja la primera página', () {
      const paginacion = Paginacion(pagina: 4, porPagina: 10, total: 37);

      final vacia = paginacion.conTotal(0);

      expect(vacia.pagina, 1);
      expect(vacia.paginas, 1);
    });
  });

  test('volver a la primera página conserva el tamaño y el total', () {
    const paginacion = Paginacion(pagina: 3, porPagina: 25, total: 100);

    expect(paginacion.primera(), const Paginacion(porPagina: 25, total: 100));
  });
}
