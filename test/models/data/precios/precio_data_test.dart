import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/extensions/int_ext.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

/// El número de días se guarda a secas —con él se calculan las fechas— y se
/// escribe con su unidad. Lo que se comprueba aquí es el singular, que es lo
/// que se escapa al escribirlo en cada pantalla.
void main() {
  PrecioData conDias(int dias) => PrecioData(
    categoriaId: 1,
    categoria: 'Lavandería',
    nombreConcepto: 'Playera',
    diasEntrega: dias,
  );

  group('los días de entrega con su unidad', () {
    test('uno va en singular', () {
      expect(conDias(1).diasFormato, '1 día');
      expect(1.enDias, '1 día');
    });

    test('los demás van en plural', () {
      expect(conDias(3).diasFormato, '3 días');
      expect(conDias(0).diasFormato, '0 días');
      expect(15.enDias, '15 días');
    });

    test('el número se conserva para calcular con él', () {
      expect(conDias(1).diasEntrega, 1);
    });
  });
}
