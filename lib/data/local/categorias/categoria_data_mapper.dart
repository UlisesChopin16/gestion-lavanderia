import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';

/// Traducción entre las filas de categorías y [CategoriaData].
///
/// Vive del lado de los datos, en extensiones, por lo mismo que la de
/// clientes: el modelo no importa drift, y a una fila generada sólo se le
/// puede agregar comportamiento desde fuera.
extension CategoriaEntryToData on CategoriaServicioEntry {
  CategoriaData toData() => CategoriaData(
    id: id,
    nombre: nombre,
    estatus: estatus,
    diasEntrega: diasEntrega,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion,
    fechaEliminacion: fechaEliminacion,
  );
}

extension CategoriasEntryToData on Iterable<CategoriaServicioEntry> {
  List<CategoriaData> toData() => map((fila) => fila.toData()).toList();
}

extension CategoriaDataToCompanion on CategoriaData {
  /// Las columnas que el formulario de la categoría gobierna.
  ///
  /// Las fechas de auditoría quedan fuera: las escribe el DAO. El estatus sí
  /// viaja, porque un alta lo necesita —la columna no admite nulos— y en una
  /// edición es el que la categoría ya traía.
  CategoriaServicioCompanion toCompanion() => CategoriaServicioCompanion(
    id: esNueva ? const Value.absent() : Value(id),
    nombre: Value(nombre),
    estatus: Value(estatus),
    diasEntrega: Value(diasEntrega),
  );
}
