import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/view_model/categorias_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba lo que una categoría arrastra consigo: sus conceptos se
/// desactivan con ella, heredan sus días de entrega, y el listado de precios
/// —si está abierto en la otra pestaña— se entera sin que nadie lo recargue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  CategoriasViewModel notificador() =>
      container.read(categoriasViewModelProvider.notifier);

  CategoriasState estado() => container.read(categoriasViewModelProvider);

  PreciosState estadoPrecios() => container.read(preciosViewModelProvider);

  Future<bool> alta({String nombre = 'Ropa de cama', int dias = 2}) =>
      notificador().guardar(CategoriaData(nombre: nombre, diasEntrega: dias));

  /// Da de alta una categoría y devuelve su id.
  Future<int> crear({String nombre = 'Ropa de cama', int dias = 2}) async {
    await alta(nombre: nombre, dias: dias);

    return estado().categorias.firstWhere((fila) => fila.nombre == nombre).id;
  }

  /// Un concepto dentro de [categoriaId], escrito por la vía normal.
  Future<void> crearConcepto(int categoriaId, {String nombre = 'Sábana'}) async {
    final guardado = await container
        .read(preciosViewModelProvider.notifier)
        .guardar(
          PrecioData(
            categoriaId: categoriaId,
            categoria: '',
            nombreConcepto: nombre,
            diasEntrega: 2,
            importe: 50,
          ),
        );

    expect(guardado, isTrue);
  }

  /// Deja vivo el listado de precios, como cuando está abierto en su pestaña.
  void mirarPrecios() {
    final suscripcion = container.listen(preciosViewModelProvider, (_, _) {});
    addTearDown(suscripcion.close);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    container = ProviderContainer();
    addTearDown(container.dispose);

    await notificador().cargar();
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  group('al escribir', () {
    test('el alta aparece en el listado', () async {
      expect(await alta(nombre: 'Planchado'), isTrue);

      expect(estado().pagina.single.nombre, 'Planchado');
      expect(estado().paginacion.total, 1);
    });

    test('un nombre repetido no se guarda y deja el motivo a la vista',
        () async {
      await alta(nombre: 'Planchado');

      expect(await alta(nombre: 'planchado'), isFalse);

      expect(estado().mensajeError, contains('Ya existe una categoría'));
      expect(estado().paginacion.total, 1);
    });
  });

  group('la baja', () {
    test('saca la categoría del listado de activas', () async {
      final id = await crear(nombre: 'Planchado');

      expect(await notificador().desactivar(id), isTrue);

      // El filtro de omisión muestra sólo las activas.
      expect(estado().categorias, isEmpty);
    });

    test('arrastra a los conceptos de la categoría', () async {
      final id = await crear();
      await crearConcepto(id);
      mirarPrecios();

      await container
          .read(preciosViewModelProvider.notifier)
          .filtrarEstatus(null);

      expect(estadoPrecios().precios.single.estaActivo, isTrue);

      await notificador().desactivar(id);

      // La recarga del listado de precios la dispara la baja; se deja correr
      // antes de mirarlo.
      await pumpEventQueue();

      expect(estadoPrecios().precios.single.estaActivo, isFalse);
    });

    test('se deshace al activar de nuevo', () async {
      final id = await crear();
      await crearConcepto(id);
      await notificador().desactivar(id);

      expect(await notificador().activar(id), isTrue);

      expect(estado().pagina.single.estatus, EstatusType.activo);

      await container.read(preciosViewModelProvider.notifier).cargar();
      expect(estadoPrecios().precios.single.estaActivo, isTrue);
    });
  });

  test('cambiar los días de entrega se los cambia a sus conceptos', () async {
    final id = await crear(dias: 2);
    await crearConcepto(id);

    expect(
      await notificador().guardar(
        estado().categorias
            .firstWhere((categoria) => categoria.id == id)
            .copyWith(diasEntrega: 5),
      ),
      isTrue,
    );

    await container.read(preciosViewModelProvider.notifier).cargar();

    expect(estado().pagina.single.diasEntrega, 5);
    expect(estadoPrecios().precios.single.diasEntrega, 5);
  });

  test('el filtro de estatus decide qué se ve', () async {
    final id = await crear(nombre: 'Planchado');
    await notificador().desactivar(id);

    // Sin filtro de estatus se ven todas, activas o no.
    await notificador().filtrarEstatus(null);
    expect(estado().paginacion.total, 1);

    await notificador().filtrarEstatus(EstatusType.inactivo);
    expect(estado().pagina.single.nombre, 'Planchado');

    await notificador().filtrarEstatus(EstatusType.activo);
    expect(estado().categorias, isEmpty);
  });

  test('quitar el filtro de estatus se recuerda al volver', () async {
    await notificador().filtrarEstatus(null);

    // Un modelo nuevo —como al volver a abrir la pestaña— sigue sin filtrar
    // por estatus: "ver todas" es una elección, no un hueco que se rellene
    // con el valor de omisión.
    final otro = ProviderContainer();
    addTearDown(otro.dispose);

    expect(otro.read(categoriasViewModelProvider).filtros.estatus, isNull);
  });
}
