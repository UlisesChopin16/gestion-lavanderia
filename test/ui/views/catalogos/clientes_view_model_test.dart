import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/view_model/clientes_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba lo que la pantalla de clientes promete: que una escritura deja el
/// listado al día sin que nadie lo recargue a mano, que lo que la base rechaza
/// llega como un motivo legible, y que la lista se pagina.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  ClientesViewModel notificador() =>
      container.read(clientesViewModelProvider.notifier);

  ClientesState estado() => container.read(clientesViewModelProvider);

  /// Da de alta un cliente con los datos de contacto que se le pasen.
  Future<bool> alta({
    String nombres = 'Juan',
    String apellidos = 'Pérez',
    String telefono = '5512345678',
    String correo = '',
  }) {
    return notificador().guardar(
      nombres: nombres,
      apellidos: apellidos,
      telefono: telefono,
      correo: correo,
    );
  }

  List<String> nombresEnPagina() =>
      estado().pagina.map((cliente) => cliente.nombres).toList();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    container = ProviderContainer();
    addTearDown(container.dispose);

    // `build` arranca la lectura en una microtarea; se espera la misma llamada
    // para no depender de cuántos ciclos tarde.
    await notificador().cargar();
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  group('al escribir', () {
    test('el alta aparece en el listado sin recargar a mano', () async {
      expect(await alta(nombres: 'Ana'), isTrue);

      expect(nombresEnPagina(), ['Ana']);
      expect(estado().paginacion.total, 1);
      expect(estado().mensajeError, isEmpty);
    });

    test('la edición se refleja en el listado', () async {
      await alta(nombres: 'Ana');
      final ana = estado().pagina.single;

      expect(
        await notificador().guardar(
          id: ana.id,
          nombres: 'Ana María',
          apellidos: ana.apellidos,
          telefono: ana.telefono,
          correo: ana.correo,
        ),
        isTrue,
      );

      expect(nombresEnPagina(), ['Ana María']);
    });

    test('dos clientes sin correo se pueden dar de alta', () async {
      // El correo es opcional, y antes la comprobación de duplicados
      // comparaba las dos cadenas vacías y daba al segundo por repetido.
      await alta(nombres: 'Ana', telefono: '5512345678');

      expect(await alta(nombres: 'Luis', telefono: '5598765432'), isTrue);
      expect(estado().paginacion.total, 2);
    });

    test('un teléfono repetido no se guarda y deja el motivo a la vista',
        () async {
      await alta(nombres: 'Ana', telefono: '5512345678');

      expect(await alta(nombres: 'Luis', telefono: '5512345678'), isFalse);

      expect(estado().mensajeError, contains('mismos datos'));
      expect(estado().paginacion.total, 1);
    });
  });

  group('al paginar', () {
    /// Doce clientes, que no caben en una página de diez.
    Future<void> doceClientes() async {
      for (var numero = 1; numero <= 12; numero++) {
        await alta(
          nombres: 'Cliente $numero',
          telefono: '55${numero.toString().padLeft(8, '0')}',
          correo: 'cliente$numero@correo.com',
        );
      }
    }

    test('la primera página trae sólo lo que cabe', () async {
      await doceClientes();

      expect(estado().clientes.length, 12);
      expect(estado().pagina.length, 10);
      expect(estado().paginacion.paginas, 2);
    });

    test('la segunda página trae el resto', () async {
      await doceClientes();

      notificador().irAPagina(2);

      expect(estado().pagina.length, 2);
      expect(estado().paginacion.desde, 11);
    });

    test('al cambiar el tamaño de página caben todos', () async {
      await doceClientes();

      notificador().cambiarFilasPorPagina(25);

      expect(estado().pagina.length, 12);
      expect(estado().paginacion.paginas, 1);
    });

    test('al buscar se vuelve a la primera página', () async {
      await doceClientes();
      notificador().irAPagina(2);

      await notificador().buscar('Cliente 1');

      expect(estado().paginacion.pagina, 1);
      // "Cliente 1", "Cliente 10", "Cliente 11" y "Cliente 12".
      expect(estado().paginacion.total, 4);
    });

    test('la página se recorta cuando el listado encoge', () async {
      await doceClientes();
      notificador().irAPagina(2);

      await notificador().buscar('Cliente 3');

      expect(estado().paginacion.pagina, 1);
      expect(nombresEnPagina(), ['Cliente 3']);
    });
  });

  test('los filtros quedan guardados para la próxima vez', () async {
    await notificador().ordenar(ColumnClientesName.nombre, true);

    // Un modelo nuevo —como al volver a abrir la pantalla— nace con los
    // filtros que quedaron en el equipo.
    final otro = ProviderContainer();
    addTearDown(otro.dispose);

    final filtros = otro.read(clientesViewModelProvider).filtros;

    expect(filtros.ordenamiento, ColumnClientesName.nombre);
    expect(filtros.ascendente, isTrue);
  });
}
