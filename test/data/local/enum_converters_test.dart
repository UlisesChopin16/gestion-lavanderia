import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/tables/tables.dart';

/// Comprueba que los converters de enumeración no cambien lo que hay en la
/// base: guardan el mismo texto que la columna tenía cuando era un `String`.
///
/// Es lo que hace que ponerlos no requiera migración, así que conviene que un
/// test lo sostenga y no sólo un comentario.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// El texto que SQLite tiene realmente en la columna, leído sin pasar por el
  /// converter.
  Future<String> textoEnLaBase(String tabla, String columna, int id) async {
    final fila = await db
        .customSelect('SELECT $columna AS valor FROM $tabla WHERE id = $id')
        .getSingle();

    return fila.read<String>('valor');
  }

  Future<int> crearCategoria({EstatusType estatus = EstatusType.activo}) {
    return db.categoriaServicioDao.insertCategoria(
      CategoriaServicioCompanion.insert(
        nombre: 'Ropa de cama',
        estatus: estatus,
        diasEntrega: 2,
        fechaCreacion: DateTime.now(),
      ),
    );
  }

  test('el estatus se guarda como el texto de siempre', () async {
    final id = await crearCategoria();

    expect(await textoEnLaBase('categoria_servicio', 'estatus', id), 'Activo');
  });

  test('un concepto guarda tamaño, unidad y estatus como texto', () async {
    final categoriaId = await crearCategoria();

    final id = await db.preciosConceptosDao.insertPrecio(
      PreciosConceptosCompanion.insert(
        categoriaId: categoriaId,
        clotheSize: ClotheSizeType.king,
        nombreConcepto: 'Sábana',
        diasEntrega: 2,
        tipoUnidad: UnitType.kilo,
        importe: 50,
        estatus: EstatusType.inactivo,
        fechaCreacion: DateTime.now(),
      ),
    );

    expect(
      await textoEnLaBase('precios_conceptos', 'clothe_size', id),
      'Tamaño King',
      reason: 'ClotheSizeType se guarda por su description',
    );
    expect(await textoEnLaBase('precios_conceptos', 'tipo_unidad', id), 'Kg');
    expect(await textoEnLaBase('precios_conceptos', 'estatus', id), 'Inactivo');
  });

  test('la fila vuelve tipada: el texto de la base se reconstruye', () async {
    final categoriaId = await crearCategoria(estatus: EstatusType.inactivo);
    final categoria = (await db.categoriaServicioDao.getById(categoriaId))!;

    expect(categoria.estatus, EstatusType.inactivo);
  });

  test('un texto que ya no corresponde a ninguna constante no rompe la lectura', () async {
    final id = await crearCategoria();
    await db.customStatement(
      "UPDATE categoria_servicio SET estatus = 'Suspendido' WHERE id = $id",
    );

    // `fromString` cae en su valor por omisión en vez de lanzar: una base vieja
    // con un estatus que ya se renombró se sigue pudiendo abrir.
    final categoria = (await db.categoriaServicioDao.getById(id))!;
    expect(categoria.estatus, EstatusType.inactivo);
  });

  test('el estatus "todos" de una orden tampoco se guarda', () async {
    final clienteId = await db.clientesDao.insertCliente(
      ClienteCompanion.insert(
        nombres: 'Ana',
        apellidos: 'López',
        correo: 'ana@example.com',
        telefono: '5551234567',
        fechaCreacion: DateTime.now(),
      ),
    );

    await expectLater(
      db.ordenServicioDao.insertOrden(
        OrdenServicioCompanion.insert(
          clienteId: clienteId,
          folio: '',
          estatus: EstatusOrdenType.todos,
          total: 50,
          restante: 50,
          fechaCreacion: DateTime.now(),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
