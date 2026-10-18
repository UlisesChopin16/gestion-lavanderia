import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba el alta y la baja de conceptos, y los filtros con los que se
/// llega a ellos: el de categoría es además la puerta por la que entra la
/// pantalla de categorías con su "ver sus conceptos".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  PreciosViewModel notificador() =>
      container.read(preciosViewModelProvider.notifier);

  PreciosState estado() => container.read(preciosViewModelProvider);

  /// Una categoría escrita directo en la base: aquí lo que se prueba son los
  /// conceptos, y la categoría es sólo el sitio donde viven.
  Future<int> crearCategoria({String nombre = 'Ropa de cama'}) {
    return db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion(
        nombre: Value(nombre),
        estatus: const Value(EstatusType.activo),
        diasEntrega: const Value(2),
      ),
    );
  }

  Future<bool> alta({
    required int categoriaId,
    String nombre = 'Sábana',
    ClotheSizeType tamano = ClotheSizeType.king,
    double importe = 50,
  }) {
    return notificador().guardar(
      PrecioData(
        categoriaId: categoriaId,
        categoria: '',
        nombreConcepto: nombre,
        clotheSize: tamano,
        diasEntrega: 2,
        importe: importe,
      ),
    );
  }

  List<String> conceptosEnPagina() =>
      estado().pagina.map((precio) => precio.nombreConcepto).toList();

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
    test('el alta aparece en el listado con su categoría', () async {
      final categoriaId = await crearCategoria();

      expect(await alta(categoriaId: categoriaId), isTrue);

      final concepto = estado().pagina.single;
      expect(concepto.nombreConcepto, 'Sábana');
      expect(concepto.categoria, 'Ropa de cama');
      expect(estado().paginacion.total, 1);
    });

    test('la edición se refleja en el listado', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);

      final concepto = estado().pagina.single;

      expect(
        await notificador().guardar(concepto.copyWith(importe: 75)),
        isTrue,
      );

      expect(estado().pagina.single.importe, 75);
      expect(estado().paginacion.total, 1);
    });

    test('un concepto repetido no se guarda y deja el motivo a la vista',
        () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);

      expect(await alta(categoriaId: categoriaId), isFalse);

      expect(estado().mensajeError, isNotEmpty);
      expect(estado().paginacion.total, 1);
    });

    test('el mismo nombre en otro tamaño sí se guarda', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);

      expect(
        await alta(categoriaId: categoriaId, tamano: ClotheSizeType.individual),
        isTrue,
      );

      expect(estado().paginacion.total, 2);
    });
  });

  group('la baja', () {
    test('saca el concepto del listado de activos', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);

      expect(await notificador().desactivar(estado().pagina.single.id), isTrue);

      expect(estado().precios, isEmpty);
    });

    test('se deshace al activar de nuevo', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);
      final id = estado().pagina.single.id;
      await notificador().desactivar(id);

      expect(await notificador().activar(id), isTrue);

      expect(estado().pagina.single.estaActivo, isTrue);
    });
  });

  group('los filtros', () {
    test('la categoría deja a la vista sólo sus conceptos', () async {
      final cama = await crearCategoria();
      final fina = await crearCategoria(nombre: 'Ropa fina');
      await alta(categoriaId: cama);
      await alta(categoriaId: fina, nombre: 'Camisa');

      await notificador().filtrarPorCategoria(fina);

      expect(conceptosEnPagina(), ['Camisa']);

      await notificador().quitarCategoria();

      expect(estado().paginacion.total, 2);
    });

    test('llegar desde una categoría dada de baja muestra sus conceptos',
        () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);

      // La baja en cascada deja el concepto inactivo: con el filtro de
      // omisión —sólo activos— la lista saldría vacía.
      await db.categoriaServicioDao.deleteCategoria(categoriaId);
      await db.preciosConceptosDao.deactivatePreciosByCategoria(categoriaId);

      await notificador().filtrarPorCategoria(
        categoriaId,
        incluirInactivos: true,
      );

      expect(conceptosEnPagina(), ['Sábana']);
      expect(estado().filtros.estatus, isNull);
    });

    test('el buscador filtra por el nombre del concepto', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);
      await alta(categoriaId: categoriaId, nombre: 'Camisa');

      await notificador().buscar('cami');

      expect(conceptosEnPagina(), ['Camisa']);
    });

    test('limpiarlos devuelve el listado completo', () async {
      final categoriaId = await crearCategoria();
      await alta(categoriaId: categoriaId);
      await notificador().buscar('nada que coincida');

      expect(estado().precios, isEmpty);

      await notificador().limpiarFiltros();

      expect(estado().paginacion.total, 1);
      expect(estado().filtros.haveFilters, isFalse);
    });
  });

  group('las categorías que ofrece', () {
    test('el formulario sólo recibe las activas', () async {
      await crearCategoria();
      final fina = await crearCategoria(nombre: 'Ropa fina');
      await db.categoriaServicioDao.deleteCategoria(fina);

      await notificador().cargar();

      // El filtro las ve todas; el formulario, sólo donde se puede dar de alta.
      expect(estado().categorias.length, 2);
      expect(
        estado().categoriasActivas.map((fila) => fila.nombre),
        ['Ropa de cama'],
      );
      expect(estado().puedeAgregar, isTrue);
    });

    test('sin categorías activas no se puede agregar', () async {
      final id = await crearCategoria();
      await db.categoriaServicioDao.deleteCategoria(id);

      await notificador().cargar();

      expect(estado().puedeAgregar, isFalse);
    });
  });
}
