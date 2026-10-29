import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/tables/tables.dart';

/// Comprueba que el esquema que drift crea sea el documentado en DATABASE.md:
/// las ocho tablas, sus índices y las claves ajenas activas.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Set<String>> nombresDe(String tipo) async {
    final filas = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = '$tipo'")
        .get();

    return filas.map((fila) => fila.read<String>('name')).toSet();
  }

  test('crea las ocho tablas', () async {
    expect(
      await nombresDe('table'),
      containsAll([
        'cliente',
        'categoria_servicio',
        'precios_conceptos',
        'orden_servicio',
        'item_servicio_orden',
        'orden_history',
        'configuracion_empresa',
        'direccion',
      ]),
    );
  });

  test('crea los índices de las claves ajenas y de las búsquedas', () async {
    expect(
      await nombresDe('index'),
      containsAll([
        'idx_cliente_correo',
        'idx_cliente_telefono',
        'idx_categoria_estatus',
        'idx_categoria_nombre',
        'idx_precio_categoria',
        'idx_precio_estatus',
        'idx_precio_unico',
        'idx_orden_folio',
        'idx_orden_cliente',
        'idx_orden_estatus',
        'idx_orden_fecha_creacion',
        'idx_item_orden',
        'idx_item_precio_concepto',
        'idx_item_history',
        'idx_history_orden_fecha',
        'idx_direccion_empresa',
      ]),
    );
  });

  test('nace en la versión 5 del esquema', () async {
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((fila) => fila.read<int>('user_version'))
        .getSingle();

    expect(version, 5);
  });

  test('las claves ajenas están activas', () async {
    final activas = await db
        .customSelect('PRAGMA foreign_keys')
        .map((fila) => fila.read<int>('foreign_keys'))
        .getSingle();

    expect(activas, 1);
  });

  test('el folio es consecutivo por mes', () async {
    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );

    final primera = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.enCurso,
        total: 100,
        restante: 0,
        fechaCreacion: DateTime.now(),
      ),
    );
    final segunda = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.enCurso,
        total: 50,
        restante: 50,
        fechaCreacion: DateTime.now(),
      ),
    );

    // `AAMM-`: los dos últimos dígitos del año y el mes.
    final ahora = DateTime.now();
    final anio = (ahora.year % 100).toString().padLeft(2, '0');
    final prefijo = '$anio${ahora.month.toString().padLeft(2, '0')}-';

    expect(primera.folio, '${prefijo}0001');
    expect(segunda.folio, '${prefijo}0002');
  });

  test('rechaza un cliente con el mismo correo en otras mayúsculas', () async {
    ClienteCompanion cliente(String correo) => ClienteCompanion.insert(
      nombres: 'Ana',
      apellidos: 'López',
      correo: correo,
      telefono: '5551234567',
      fechaCreacion: DateTime.now(),
    );

    await db.clientesDao.insertCliente(cliente('ana@example.com'));

    expect(
      () => db.clientesDao.insertCliente(cliente('Ana@Example.com')),
      throwsA(isA<Exception>()),
    );
  });
}
