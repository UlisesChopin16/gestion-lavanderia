import 'package:drift/drift.dart';

/// Columnas de auditoría presentes en toda tabla que se crea y edita.
///
/// Están en un mixin para que agregar o cambiar una columna de auditoría se
/// haga en un solo lugar en vez de repetirse en cada tabla.
mixin TimestampColumns on Table {
  DateTimeColumn get fechaCreacion => dateTime()();
  DateTimeColumn get fechaActualizacion => dateTime().nullable()();
}

/// Baja lógica.
///
/// En esta aplicación ningún registro se borra físicamente: "eliminar" en la
/// interfaz significa desactivar, y [fechaEliminacion] guarda el momento en
/// que eso ocurrió. Siempre viaja junto con la columna `estatus`, que es la
/// única fuente de verdad sobre la visibilidad.
mixin SoftDeleteColumn on Table {
  DateTimeColumn get fechaEliminacion => dateTime().nullable()();
}
