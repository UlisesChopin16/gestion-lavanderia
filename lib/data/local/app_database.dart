import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:gestion_lavanderia/models/tables/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Cliente,
    OrdenServicio,
    ItemServicioOrden,
    ConfiguracionEmpresa,
    Direccion,
    CategoriaServicio,
    PreciosConceptos,
    OrdenHistory,
  ],
  daos: [
    ClientesDao,
    OrdenServicioDao,
    ItemServicioOrdenDao,
    ConfiguracionEmpresaDao,
    DireccionDao,
    CategoriaServicioDao,
    PreciosConceptosDao,
    OrdenHistoryDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await _migrarAVersion2(m);
      if (from < 3) await _migrarAVersion3(m);
      if (from < 4) await _migrarAVersion4(m);
    },
    beforeOpen: (details) async {
      // Las tablas declaran `references`, pero SQLite no las hace cumplir si
      // no se habilita el pragma en cada conexión. Es seguro activarlo porque
      // en esta base nada se borra físicamente: las bajas son lógicas, así que
      // ninguna referencia puede quedar huérfana.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Versión 2: corrige el nombre de `fecha_entegado` y crea los índices de las
  /// claves ajenas y de las búsquedas por igualdad.
  ///
  /// Hasta la versión 1 no existía ningún índice, así que cada join y cada
  /// verificación de duplicados recorría la tabla completa. Una base creada
  /// desde cero nace ya en la última versión y no pasa por aquí; el paso sólo
  /// corre al abrir un `app.db` que venga de la versión 1.
  Future<void> _migrarAVersion2(Migrator m) async {
    await m.renameColumn(
      itemServicioOrden,
      'fecha_entegado',
      itemServicioOrden.fechaEntregado,
    );

    for (final indice in allSchemaEntities.whereType<Index>()) {
      if (_indicesVersion2.contains(indice.entityName)) await m.create(indice);
    }
  }

  /// Versión 3: cada item guarda en qué movimiento del historial se entregó.
  ///
  /// La columna nace nula —ninguna entrega anterior sabe a qué movimiento
  /// pertenece— y los items ya entregados conservan su `fecha_entregado`.
  Future<void> _migrarAVersion3(Migrator m) async {
    await m.addColumn(itemServicioOrden, itemServicioOrden.ordenHistoryId);
    await m.create(idxItemHistory);
  }

  /// Versión 4: cada pago en efectivo guarda con cuánto pagó el cliente.
  ///
  /// La columna nace nula: los pagos anteriores no lo registraban, y poner ahí
  /// el monto sería inventar que todos pagaron justo.
  Future<void> _migrarAVersion4(Migrator m) async {
    await m.addColumn(ordenHistory, ordenHistory.recibido);
  }

  /// Los índices que el esquema tenía en la versión 2.
  ///
  /// Cada paso crea sólo los suyos, nombrados. Recorrer `allSchemaEntities` sin
  /// filtrar parecía más corto, pero esa lista es la del esquema de hoy: al
  /// migrar una base de la versión 1 incluiría índices de columnas que todavía
  /// no existen —el `CREATE INDEX` falla— y además los volvería a crear el paso
  /// que los introdujo.
  static const _indicesVersion2 = {
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
    'idx_history_orden_fecha',
    'idx_direccion_empresa',
  };
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    debugPrint('Database file path: ${file.path}');
    return NativeDatabase(file);
  });
}
