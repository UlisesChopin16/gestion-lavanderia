import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/dialogs/formulario_precio.dart';

/// Las reglas del formulario de un concepto, sin pantalla.
void main() {
  const lavado = CategoriaData(id: 1, nombre: 'Lavado', diasEntrega: 2);
  const planchado = CategoriaData(id: 2, nombre: 'Planchado', diasEntrega: 1);

  test('un alta arma un concepto por categoría, con lo común repetido', () {
    final formulario = const FormularioPrecio.alta()
        .conNombre('Playera')
        .conUnidad(UnitType.pieza)
        .alternarCategoria(lavado)
        .alternarCategoria(planchado)
        .conImporte(lavado, '30')
        .conImporte(planchado, '20');

    final conceptos = formulario.conceptos;

    expect(conceptos.map((c) => c.categoriaId), [1, 2]);
    expect(conceptos.map((c) => c.nombreConcepto), ['Playera', 'Playera']);
    expect(conceptos.map((c) => c.importe), [30, 20]);
    expect(conceptos.map((c) => c.diasEntrega), [2, 1]);
    expect(conceptos.every((c) => c.esNuevo), isTrue);
    expect(formulario.completo, isTrue);
  });

  test('quitar una categoría y volver a elegirla conserva lo escrito', () {
    final formulario = const FormularioPrecio.alta()
        .alternarCategoria(lavado)
        .conImporte(lavado, '30')
        .conDias(lavado, '4')
        .alternarCategoria(lavado)
        .alternarCategoria(lavado);

    expect(formulario.precioDe(lavado).importe, '30');
    expect(formulario.precioDe(lavado).dias, '4');
  });

  test('al editar es una sola categoría y conserva el id', () {
    final formulario = FormularioPrecio.edicion(
      const PrecioData(
        id: 7,
        categoriaId: 1,
        categoria: 'Lavado',
        nombreConcepto: 'Playera',
        diasEntrega: 9,
        importe: 30,
      ),
    ).alternarCategoria(planchado);

    final concepto = formulario.conceptos.single;

    expect(concepto.id, 7);
    expect(concepto.categoriaId, 2);
    expect(concepto.diasEntrega, 9);
    expect(concepto.importe, 30);
  });

  test('usar el importe de una en todas no toca los días', () {
    final formulario = const FormularioPrecio.alta()
        .alternarCategoria(lavado)
        .alternarCategoria(planchado)
        .conImporte(lavado, '30')
        .conImporteEnTodas(lavado);

    expect(formulario.precioDe(planchado).importe, '30');
    expect(formulario.precioDe(planchado).dias, '1');
  });

  test('dice cuál categoría está incompleta', () {
    final formulario = const FormularioPrecio.alta()
        .conNombre('Playera')
        .alternarCategoria(lavado)
        .alternarCategoria(planchado)
        .conImporte(lavado, '30');

    expect(formulario.primeraIncompleta, planchado);
    expect(formulario.completo, isFalse);
  });
}
