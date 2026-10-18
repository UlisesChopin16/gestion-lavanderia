import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/datasource/local/filtros_store.dart';
import 'package:gestion_lavanderia/models/data/clientes/filtros_clientes.dart';
import 'package:gestion_lavanderia/models/data/precios/filtros_precios.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba el ida y vuelta de los filtros a las preferencias del equipo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FiltrosStore> store([Map<String, Object> guardado = const {}]) async {
    SharedPreferences.setMockInitialValues(guardado);
    return FiltrosStore(await SharedPreferences.getInstance());
  }

  test('sin nada guardado devuelve los filtros por omisión', () async {
    final filtros = (await store()).precios;

    expect(filtros, FiltrosPrecios.porOmision);
    expect(filtros.haveFilters, isFalse);
  });

  test('guarda y vuelve a leer todos los campos', () async {
    final filtrosStore = await store();
    const filtros = FiltrosPrecios(
      nombre: 'sábana',
      estatus: null,
      ascendente: true,
      categoriaId: 3,
      clotheSize: ClotheSizeType.king,
      ordenamiento: ColumnPreciosName.importe,
    );

    await filtrosStore.guardarPrecios(filtros);

    expect(filtrosStore.precios, filtros);
  });

  test('cada módulo guarda en su propia llave', () async {
    final filtrosStore = await store();

    await filtrosStore.guardarPrecios(const FiltrosPrecios(nombre: 'toalla'));

    expect(filtrosStore.precios.nombre, 'toalla');
    expect(filtrosStore.clientes, const FiltrosClientes());
  });

  test('las enumeraciones se guardan por el nombre de la constante', () async {
    final filtrosStore = await store();

    await filtrosStore.guardarPrecios(
      const FiltrosPrecios(clotheSize: ClotheSizeType.king),
    );

    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString('filtros_precios')!) as Map<String, dynamic>;

    expect(json['clotheSize'], 'king');
  });

  test('descarta un JSON que ya no coincide con el modelo', () async {
    final filtrosStore = await store({
      'filtros_precios': jsonEncode({'ordenamiento': 'columnaQueYaNoExiste'}),
    });

    expect(filtrosStore.precios, FiltrosPrecios.porOmision);

    // La llave inservible se borra, para no volver a intentar leerla.
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('filtros_precios'), isNull);
  });
}
