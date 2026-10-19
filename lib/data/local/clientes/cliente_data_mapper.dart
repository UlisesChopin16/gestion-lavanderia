import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';

/// Traducción entre las filas de clientes y [ClienteData].
///
/// Vive del lado de los datos, en extensiones, y no en el modelo: si el mapeo
/// estuviera en [ClienteData], ese archivo tendría que importar drift y el
/// modelo quedaría amarrado a la base, que es justo lo que se quiere evitar.
/// Las extensiones además son la única forma de agregarle métodos a una fila
/// generada, que no se puede modificar.
extension ClienteEntryToData on ClienteEntry {
  ClienteData toData() => ClienteData(
    id: id,
    nombres: nombres,
    apellidos: apellidos,
    correo: correo,
    telefono: telefono,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion,
    fechaEliminacion: fechaEliminacion,
  );
}

extension ClientesEntryToData on Iterable<ClienteEntry> {
  List<ClienteData> toData() => map((fila) => fila.toData()).toList();
}

extension ClienteDataToCompanion on ClienteData {
  /// Las columnas que el formulario del cliente gobierna.
  ///
  /// Las fechas de auditoría quedan fuera a propósito: las escribe el DAO. Un
  /// companion con sólo lo que el formulario cambió es también lo que
  /// `updateCliente` espera, porque lo ausente se queda como está.
  ClienteCompanion toCompanion() => ClienteCompanion(
    id: esNuevo ? const Value.absent() : Value(id),
    nombres: Value(nombres),
    apellidos: Value(apellidos),
    correo: Value(correo),
    telefono: Value(telefono),
  );
}
