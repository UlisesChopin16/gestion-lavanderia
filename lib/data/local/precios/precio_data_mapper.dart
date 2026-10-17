import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/precios/precio_con_detalles_entry.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

/// Traducción entre las filas de precios y [PrecioData].
///
/// Vive del lado de los datos, en extensiones, y no en el modelo: si el mapeo
/// estuviera en [PrecioData], ese archivo tendría que importar drift y el modelo
/// quedaría amarrado a la base, que es justo lo que se quiere evitar. Las
/// extensiones además son la única forma de agregarle métodos a una fila
/// generada, que no se puede modificar.
extension PrecioConDetallesToData on PrecioConDetallesEntry {
  PrecioData toData() => PrecioData(
    id: precio.id,
    categoriaId: precio.categoriaId,
    categoria: categoria.nombre,
    nombreConcepto: precio.nombreConcepto,
    clotheSize: precio.clotheSize,
    diasEntrega: precio.diasEntrega,
    tipoUnidad: precio.tipoUnidad,
    importe: precio.importe,
    estatus: precio.estatus,
    fechaCreacion: precio.fechaCreacion,
    fechaActualizacion: precio.fechaActualizacion,
    fechaEliminacion: precio.fechaEliminacion,
  );
}

extension PreciosConDetallesToData on Iterable<PrecioConDetallesEntry> {
  List<PrecioData> toData() => map((fila) => fila.toData()).toList();
}

extension PrecioDataToCompanion on PrecioData {
  /// Las columnas que el formulario de precios gobierna.
  ///
  /// Quedan fuera a propósito: `categoria`, que es el nombre con el que se
  /// muestra la categoría y no una columna de esta tabla, y las fechas de
  /// auditoría, que las escribe el DAO. Un companion con sólo lo que el
  /// formulario cambió es también lo que `updatePrecio` espera, porque lo
  /// ausente se queda como está.
  PreciosConceptosCompanion toCompanion() => PreciosConceptosCompanion(
    id: esNuevo ? const Value.absent() : Value(id),
    categoriaId: Value(categoriaId),
    clotheSize: Value(clotheSize),
    nombreConcepto: Value(nombreConcepto),
    diasEntrega: Value(diasEntrega),
    tipoUnidad: Value(tipoUnidad),
    importe: Value(importe),
    estatus: Value(estatus),
  );
}
