import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/detalle/view_model/orden_detalle_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Comprueba las reglas del detalle de una orden: qué se puede entregar, qué
/// se puede cobrar, cuándo sólo queda un resumen y qué se escribe al
/// registrar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late int clienteId;

  /// La sábana cuesta 50 y la cobija 120: una orden con las dos suma 170.
  late PrecioData sabana;
  late PrecioData cobija;

  OrdenesLocalDatasource ordenes() => instance<OrdenesLocalDatasource>();

  OrdenDetalleViewModel notificador(int ordenId) =>
      container.read(ordenDetalleViewModelProvider(ordenId).notifier);

  OrdenDetalleState estado(int ordenId) =>
      container.read(ordenDetalleViewModelProvider(ordenId));

  ItemOrdenData renglon(PrecioData precio) =>
      ItemOrdenData(precio: precio, fechaEntrega: DateTime(2026, 10, 25));

  /// Una orden con una sábana y una cobija, abierta en el detalle.
  Future<int> abrirOrden({
    double abono = 0,
    MetodoPagoType metodoPago = MetodoPagoType.efectivo,
  }) async {
    final orden = await ordenes().crearOrden(
      clienteId: clienteId,
      items: [renglon(sabana), renglon(cobija)],
      abono: abono,
      metodoPago: metodoPago,
    );

    // Escuchado para que el proveedor no se deseche entre una lectura y la
    // siguiente: el diálogo lo tiene vivo mientras está abierto.
    container.listen(ordenDetalleViewModelProvider(orden.id), (_, _) {});
    await notificador(orden.id).cargar();

    return orden.id;
  }

  ItemOrdenData item(int ordenId, String concepto) =>
      estado(ordenId).orden!.items.firstWhere((i) => i.concepto == concepto);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);

    container = ProviderContainer();
    addTearDown(container.dispose);

    clienteId = await db.clientesDao.insertCliente(
      const ClienteCompanion(
        nombres: Value('Lucía'),
        apellidos: Value('Pérez'),
        telefono: Value('5559998888'),
        correo: Value('lucia@correo.com'),
      ),
    );

    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      const CategoriaServicioCompanion(
        nombre: Value('Ropa de cama'),
        estatus: Value(EstatusType.activo),
        diasEntrega: Value(2),
      ),
    );

    for (final (nombre, importe) in [('Sábana', 50.0), ('Cobija', 120.0)]) {
      await db.preciosConceptosDao.insertPrecio(
        PreciosConceptosCompanion(
          categoriaId: Value(categoriaId),
          clotheSize: const Value(ClotheSizeType.emptySize),
          nombreConcepto: Value(nombre),
          diasEntrega: const Value(2),
          tipoUnidad: const Value(UnitType.pieza),
          importe: Value(importe),
          estatus: const Value(EstatusType.activo),
        ),
      );
    }

    final catalogo = await instance<PreciosLocalDatasource>().activos();
    sabana = catalogo.firstWhere((p) => p.nombreConcepto == 'Sábana');
    cobija = catalogo.firstWhere((p) => p.nombreConcepto == 'Cobija');
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  test('al abrir lee la orden y no marca nada', () async {
    final id = await abrirOrden();

    expect(estado(id).orden?.total, 170);
    expect(estado(id).aEntregar, isEmpty);
    expect(estado(id).soloResumen, isFalse);
    // Sin cobrar ni entregar nada, no hay nada que registrar.
    expect(estado(id).puedeRegistrar, isFalse);
  });

  group('la entrega', () {
    test('una parte de la ropa sale aunque no esté pagada', () async {
      final id = await abrirOrden();

      notificador(id).alternarEntrega(item(id, 'Sábana'));

      expect(estado(id).entregaTodo, isFalse);
      expect(estado(id).faltaPagarParaEntregarTodo, isFalse);
      expect(estado(id).puedeRegistrar, isTrue);
    });

    test('toda la ropa no sale si la orden no queda pagada', () async {
      final id = await abrirOrden(abono: 20);

      notificador(id).marcarTodo(true);

      expect(estado(id).entregaTodo, isTrue);
      expect(estado(id).faltaPagarParaEntregarTodo, isTrue);
      expect(estado(id).puedeRegistrar, isFalse);

      // Un pago parcial no basta: tiene que quedar en cero.
      notificador(id).cambiarAbono(100);
      expect(estado(id).puedeRegistrar, isFalse);

      // Pagando lo que falta en el mismo movimiento, sí.
      notificador(id).abonarTodo();
      expect(estado(id).abono, 150);
      expect(estado(id).faltaPagarParaEntregarTodo, isFalse);
      expect(estado(id).puedeRegistrar, isTrue);
    });

    test('si ya está pagada, toda la ropa sale sin cobrar nada', () async {
      final id = await abrirOrden(abono: 170);

      notificador(id).marcarTodo(true);

      expect(estado(id).pagada, isTrue);
      expect(estado(id).puedeRegistrar, isTrue);
    });

    test('lo ya entregado no se vuelve a marcar', () async {
      final id = await abrirOrden();
      await ordenes().registrarMovimiento(
        ordenId: id,
        itemsAEntregar: [item(id, 'Sábana').id],
      );
      await notificador(id).cargar();

      notificador(id).alternarEntrega(item(id, 'Sábana'));
      expect(estado(id).aEntregar, isEmpty);

      // Marcar todo es marcar lo que falta: sólo la cobija.
      notificador(id).marcarTodo(true);
      expect(estado(id).aEntregar, [item(id, 'Cobija').id]);
    });
  });

  group('el cobro', () {
    test('no pasa de lo que se debe', () async {
      final id = await abrirOrden(abono: 20);

      notificador(id).cambiarAbono(1000);

      expect(estado(id).abono, 150);
    });

    test('en efectivo saca el cambio y avisa si no alcanza', () async {
      final id = await abrirOrden();

      notificador(id).cambiarAbono(100);
      notificador(id).cambiarRecibido(500);

      expect(estado(id).cambio, 400);
      expect(estado(id).recibidoInsuficiente, isFalse);
      expect(estado(id).puedeRegistrar, isTrue);

      notificador(id).cambiarRecibido(50);

      expect(estado(id).recibidoInsuficiente, isTrue);
      expect(estado(id).puedeRegistrar, isFalse);
    });

    test('sin efectivo no hay nada recibido que contar', () async {
      final id = await abrirOrden();

      notificador(id).cambiarAbono(100);
      notificador(id).cambiarRecibido(50);
      notificador(id).elegirMetodoPago(MetodoPagoType.tarjeta);

      expect(estado(id).recibido, 0);
      expect(estado(id).recibidoInsuficiente, isFalse);
    });
  });

  group('al registrar', () {
    test('cobra y entrega en un solo movimiento, y lo dice', () async {
      final id = await abrirOrden();

      notificador(id).abonarTodo();
      notificador(id).marcarTodo(true);

      final mensaje = await notificador(id).registrar();

      expect(
        mensaje,
        allOf(
          contains('el pago de 170.00'),
          contains('la entrega de 2 conceptos'),
          contains('quedó pagada y entregada'),
        ),
      );

      final orden = await ordenes().detalle(id);
      expect(orden?.estatus, EstatusOrdenType.cerrada);
      expect(orden?.restante, 0);
      expect(orden?.todoEntregado, isTrue);
    });

    test('en efectivo guarda con cuánto pagó el cliente', () async {
      final id = await abrirOrden();

      notificador(id).cambiarAbono(170);
      notificador(id).cambiarRecibido(500);
      await notificador(id).registrar();

      final pago = (await ordenes().detalle(id))!.ultimoMovimiento!;
      expect(pago.recibido, 500);
      expect(pago.cambio, 330);
    });

    test('sin escribir con cuánto paga, se guarda que pagó justo', () async {
      final id = await abrirOrden();

      notificador(id).cambiarAbono(100);
      await notificador(id).registrar();

      final pago = (await ordenes().detalle(id))!.ultimoMovimiento!;
      expect(pago.recibido, 100);
      expect(pago.cambio, 0);
    });

    test('con tarjeta no se guarda efectivo recibido', () async {
      final id = await abrirOrden();

      notificador(id).elegirMetodoPago(MetodoPagoType.tarjeta);
      notificador(id).cambiarAbono(100);
      await notificador(id).registrar();

      final pago = (await ordenes().detalle(id))!.ultimoMovimiento!;
      expect(pago.recibido, isNull);
    });

    test('una entrega sin cobro no cambia el método de pago', () async {
      final id = await abrirOrden(
        abono: 20,
        metodoPago: MetodoPagoType.tarjeta,
      );

      notificador(id).alternarEntrega(item(id, 'Sábana'));
      await notificador(id).registrar();

      // El listado enseña el método del último movimiento: recoger ropa no
      // es pagar en efectivo.
      final listado = await ordenes().listado();
      expect(listado.single.metodoPago, MetodoPagoType.tarjeta);
    });
  });

  group('el resumen', () {
    test('pagada con ropa pendiente sigue abierta para entregar', () async {
      final id = await abrirOrden(abono: 170);

      expect(estado(id).pagada, isTrue);
      expect(estado(id).soloResumen, isFalse);
      expect(estado(id).admiteMovimientos, isTrue);
    });

    test('pagada y entregada sólo se resume', () async {
      final id = await abrirOrden(abono: 170);
      await ordenes().registrarMovimiento(
        ordenId: id,
        itemsAEntregar: estado(id).orden!.items.map((i) => i.id),
      );
      await notificador(id).cargar();

      expect(estado(id).soloResumen, isTrue);
      expect(estado(id).admiteMovimientos, isFalse);

      // Y ya no se puede marcar nada.
      notificador(id).marcarTodo(true);
      expect(estado(id).aEntregar, isEmpty);
    });
  });
}
