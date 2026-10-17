import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/tables/tables.dart';
import 'package:path/path.dart' as p;

/// Degrada una base al esquema de una versión anterior y la vuelve a abrir,
/// para comprobar que la migración corre y no se pierden datos.
void main() {
  late Directory dir;
  late File archivo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gestion_lavanderia_test');
    archivo = File(p.join(dir.path, 'app.db'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase abrir() => AppDatabase.forTesting(NativeDatabase(archivo));

  Future<int> versionDe(AppDatabase db) {
    return db
        .customSelect('PRAGMA user_version')
        .map((fila) => fila.read<int>('user_version'))
        .getSingle();
  }

  Future<Set<String>> indicesDe(AppDatabase db) async {
    final filas = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name LIKE 'idx_%'",
        )
        .get();

    return filas.map((fila) => fila.read<String>('name')).toSet();
  }

  /// Una orden con un item ya entregado, para comprobar que la migración no lo
  /// pierde.
  Future<int> sembrar(AppDatabase db) async {
    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );

    final categoriaId = await db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: 'Ropa de cama',
        estatus: EstatusType.activo,
        diasEntrega: 2,
        fechaCreacion: DateTime.now(),
      ),
    );

    final precioId = await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion.insert(
        categoriaId: categoriaId,
        clotheSize: ClotheSizeType.king,
        nombreConcepto: 'Sábana',
        diasEntrega: 2,
        tipoUnidad: UnitType.pieza,
        importe: 50,
        estatus: EstatusType.activo,
        fechaCreacion: DateTime.now(),
      ),
    );

    final orden = await db.ordenServicioDao.insertOrden(
      OrdenServicioCompanion.insert(
        clienteId: clienteId,
        folio: '',
        estatus: EstatusOrdenType.enCurso,
        total: 50,
        restante: 0,
        fechaCreacion: DateTime.now(),
      ),
    );

    await db.itemServicioOrdenDao.insertItem(
      ItemServicioOrdenCompanion.insert(
        ordenId: orden.id,
        precioConceptoId: precioId,
        cantidad: 1,
        importe: 50,
        estaEntregado: const Value(true),
        fechaEntrega: DateTime(2026, 10, 17),
        fechaEntregado: Value(DateTime(2026, 10, 17, 9, 30)),
        fechaCreacion: DateTime.now(),
      ),
    );

    return orden.id;
  }

  /// Deja la base como la versión 2: sin la columna que liga la entrega con su
  /// movimiento, ni su índice.
  Future<void> degradarAVersion2(AppDatabase db) async {
    await db.customStatement('DROP INDEX idx_item_history');
    await db.customStatement(
      'ALTER TABLE item_servicio_orden DROP COLUMN orden_history_id',
    );
    await db.customStatement('PRAGMA user_version = 2');
  }

  /// Deja la base como la versión 1: además de lo anterior, sin ningún índice y
  /// con el nombre viejo de `fecha_entregado`.
  Future<void> degradarAVersion1(AppDatabase db) async {
    await degradarAVersion2(db);

    for (final indice in await indicesDe(db)) {
      await db.customStatement('DROP INDEX $indice');
    }
    await db.customStatement(
      'ALTER TABLE item_servicio_orden '
      'RENAME COLUMN fecha_entregado TO fecha_entegado',
    );
    await db.customStatement('PRAGMA user_version = 1');
  }

  test('migra de la versión 2 a la 3', () async {
    var db = abrir();
    final ordenId = await sembrar(db);
    await degradarAVersion2(db);
    await db.close();

    db = abrir();
    addTearDown(db.close);

    expect(await versionDe(db), 3);
    expect(await indicesDe(db), contains('idx_item_history'));

    final items = await db.itemServicioOrdenDao.getItemsByOrden(ordenId);
    expect(items, hasLength(1));
    expect(items.single.item.estaEntregado, isTrue);
    expect(items.single.item.fechaEntregado, DateTime(2026, 10, 17, 9, 30));

    // La entrega de antes no sabe a qué movimiento pertenece, pero la columna
    // ya está lista para las siguientes.
    expect(items.single.item.ordenHistoryId, isNull);
  });

  test('migra de la versión 1 a la 3 y crea todos los índices', () async {
    var db = abrir();
    final ordenId = await sembrar(db);
    await degradarAVersion1(db);
    await db.close();

    db = abrir();
    addTearDown(db.close);

    expect(await versionDe(db), 3);
    expect(
      await indicesDe(db),
      containsAll([
        'idx_cliente_correo',
        'idx_categoria_nombre',
        'idx_precio_unico',
        'idx_orden_folio',
        'idx_item_orden',
        'idx_item_precio_concepto',
        'idx_item_history',
        'idx_history_orden_fecha',
        'idx_direccion_empresa',
      ]),
    );

    final items = await db.itemServicioOrdenDao.getItemsByOrden(ordenId);
    expect(items.single.item.fechaEntregado, DateTime(2026, 10, 17, 9, 30));
  });

  test('una base nueva nace en la versión 3 y no migra', () async {
    final db = abrir();
    addTearDown(db.close);

    expect(await versionDe(db), 3);
    expect(await indicesDe(db), contains('idx_item_history'));
  });
}
