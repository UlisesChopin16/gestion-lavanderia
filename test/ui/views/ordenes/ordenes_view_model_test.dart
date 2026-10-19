import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/view_model/ordenes_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba los filtros con los que se llega a una orden y el recorte por
/// páginas. El listado es de sólo lectura: lo que mueve una orden vive en los
/// diálogos, que se portan aparte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  OrdenesViewModel notificador() =>
      container.read(ordenesViewModelProvider.notifier);

  OrdenesState estado() => container.read(ordenesViewModelProvider);

  /// Cuántos clientes se han creado, para que cada uno tenga su teléfono: la
  /// base no admite dos iguales.
  var creados = 0;

  Future<int> crearCliente({
    String nombres = 'Ana',
    String apellidos = 'Pérez',
  }) {
    creados++;

    return db.clientesDao.insertCliente(
      ClienteCompanion(
        nombres: Value(nombres),
        apellidos: Value(apellidos),
        telefono: Value('55${creados.toString().padLeft(8, '0')}'),
        correo: Value('cliente$creados@correo.com'),
      ),
    );
  }

  /// Una orden escrita directo en la base, con su primer movimiento.
  ///
  /// Son dos tablas y no una porque el listado une cada orden con su último
  /// movimiento: una orden sin movimiento no sale en ninguna consulta. No se
  /// usa `crearOrden` del datasource porque eso pediría además una categoría y
  /// un concepto de precio, y aquí lo que se prueba son los filtros.
  Future<String> crearOrden({
    required int clienteId,
    double total = 100,
    double restante = 0,
    EstatusOrdenType estatus = EstatusOrdenType.enCurso,
    MetodoPagoType metodoPago = MetodoPagoType.efectivo,
  }) async {
    final orden = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        // El folio lo genera el DAO dentro de su transacción.
        folio: '',
        estatus: estatus,
        total: total,
        restante: restante,
        fechaCreacion: DateTime.now(),
      ),
    );

    await db.ordenHistoryDao.insertHistory(
      OrdenHistoryCompanion.insert(
        ordenId: orden.id,
        monto: total - restante,
        restante: restante,
        metodoPago: metodoPago,
        fecha: orden.fechaCreacion,
      ),
    );

    return orden.folio;
  }

  List<String> foliosEnPagina() =>
      estado().pagina.map((orden) => orden.folio).toList();

  setUp(() async {
    creados = 0;
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

  group('al leer', () {
    test('cada orden llega con su cliente y su último movimiento', () async {
      final clienteId = await crearCliente(nombres: 'Lucía');
      final folio = await crearOrden(
        clienteId: clienteId,
        total: 250,
        restante: 100,
        metodoPago: MetodoPagoType.tarjeta,
      );

      await notificador().cargar();

      final orden = estado().pagina.single;

      expect(orden.folio, folio);
      expect(orden.cliente, 'Lucía Pérez');
      expect(orden.total, 250);
      expect(orden.restante, 100);
      expect(orden.pagado, 150);
      expect(orden.metodoPago, MetodoPagoType.tarjeta);
    });

    test('sin órdenes la página queda vacía', () async {
      await notificador().cargar();

      expect(estado().pagina, isEmpty);
      expect(estado().cargando, isFalse);
    });
  });

  group('los filtros', () {
    test('la búsqueda acota por nombre del cliente', () async {
      final ana = await crearCliente(nombres: 'Ana');
      final beto = await crearCliente(nombres: 'Beto');
      final deAna = await crearOrden(clienteId: ana);
      await crearOrden(clienteId: beto);

      await notificador().buscar('Ana');

      expect(foliosEnPagina(), [deAna]);
    });

    test('la búsqueda acota por folio', () async {
      final clienteId = await crearCliente();
      final primera = await crearOrden(clienteId: clienteId);
      await crearOrden(clienteId: clienteId);

      await notificador().buscar(primera);

      expect(foliosEnPagina(), [primera]);
    });

    test('el estatus deja sólo las órdenes en ese punto', () async {
      final clienteId = await crearCliente();
      final enCurso = await crearOrden(clienteId: clienteId);
      await crearOrden(clienteId: clienteId, estatus: EstatusOrdenType.cerrada);

      await notificador().filtrarEstatus(EstatusOrdenType.enCurso);

      expect(foliosEnPagina(), [enCurso]);

      // Quitar el filtro llega como `null` desde el desplegable y se guarda
      // como `todos`, que es lo que la consulta entiende por no filtrar.
      await notificador().filtrarEstatus(null);

      expect(estado().filtros.estatus, EstatusOrdenType.todos);
      expect(foliosEnPagina(), hasLength(2));
    });

    test('el método de pago es el del último movimiento', () async {
      final clienteId = await crearCliente();
      final conTarjeta = await crearOrden(
        clienteId: clienteId,
        metodoPago: MetodoPagoType.tarjeta,
      );
      await crearOrden(clienteId: clienteId);

      await notificador().filtrarMetodoPago(MetodoPagoType.tarjeta);

      expect(foliosEnPagina(), [conTarjeta]);

      await notificador().filtrarMetodoPago(null);

      expect(foliosEnPagina(), hasLength(2));
    });

    test('el rango de fechas acota por la de creación', () async {
      final clienteId = await crearCliente();
      await crearOrden(clienteId: clienteId);

      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));

      // Un rango que terminó ayer no alcanza a lo de hoy...
      await notificador().filtrarFechas([
        ayer.subtract(const Duration(days: 7)),
        ayer,
      ]);

      expect(foliosEnPagina(), isEmpty);

      // ...y uno abierto por el final sí, que es lo que se ve mientras se
      // está eligiendo el rango en el calendario.
      await notificador().filtrarFechas([ayer]);

      expect(foliosEnPagina(), hasLength(1));
      expect(estado().rangoCreacion, [ayer]);

      await notificador().quitarFechas();

      expect(estado().rangoCreacion, isEmpty);
      expect(foliosEnPagina(), hasLength(1));
    });

    test('el ordenamiento cambia el sentido del listado', () async {
      final clienteId = await crearCliente();
      final barata = await crearOrden(clienteId: clienteId, total: 50);
      final cara = await crearOrden(clienteId: clienteId, total: 500);

      await notificador().ordenar(ColumnsOrdenesNames.total, true);

      expect(foliosEnPagina(), [barata, cara]);

      await notificador().ordenar(ColumnsOrdenesNames.total, false);

      expect(foliosEnPagina(), [cara, barata]);
    });

    test('limpiarlos devuelve el listado completo', () async {
      final ana = await crearCliente(nombres: 'Ana');
      final beto = await crearCliente(nombres: 'Beto');
      await crearOrden(clienteId: ana);
      await crearOrden(clienteId: beto, estatus: EstatusOrdenType.cerrada);

      await notificador().buscar('Ana');
      await notificador().filtrarEstatus(EstatusOrdenType.enCurso);

      expect(foliosEnPagina(), hasLength(1));

      await notificador().limpiarFiltros();

      expect(estado().filtros.haveFilters, isFalse);
      expect(foliosEnPagina(), hasLength(2));
    });
  });

  group('la paginación', () {
    /// Doce órdenes: más de una página de diez.
    Future<void> sembrarDoce() async {
      final clienteId = await crearCliente();

      for (var numero = 0; numero < 12; numero++) {
        await crearOrden(clienteId: clienteId);
      }

      await notificador().cargar();
    }

    test('recorta la página y cuenta el listado entero', () async {
      await sembrarDoce();

      expect(estado().pagina, hasLength(10));
      expect(estado().paginacion.total, 12);
      expect(estado().paginacion.paginas, 2);
    });

    test('la última página trae lo que sobra', () async {
      await sembrarDoce();

      notificador().irAPagina(2);

      expect(estado().pagina, hasLength(2));
    });

    test('filtrar vuelve a la primera página', () async {
      await sembrarDoce();

      notificador().irAPagina(2);
      await notificador().filtrarEstatus(EstatusOrdenType.enCurso);

      expect(estado().paginacion.pagina, 1);
    });

    test('cambiar el tamaño de página cabe todo en una', () async {
      await sembrarDoce();

      notificador().cambiarFilasPorPagina(25);

      expect(estado().pagina, hasLength(12));
      expect(estado().paginacion.paginas, 1);
    });
  });
}
