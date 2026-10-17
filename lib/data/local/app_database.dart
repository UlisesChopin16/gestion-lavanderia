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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await _migrarAVersion2(m);
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
  /// desde cero nace ya en la versión 2 y no pasa por aquí; el paso sólo corre
  /// al abrir un `app.db` que venga de la versión 1.
  Future<void> _migrarAVersion2(Migrator m) async {
    await m.renameColumn(
      itemServicioOrden,
      'fecha_entegado',
      itemServicioOrden.fechaEntregado,
    );

    for (final indice in allSchemaEntities.whereType<Index>()) {
      await m.create(indice);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    debugPrint('Database file path: ${file.path}');
    return NativeDatabase(file);
  });
}
