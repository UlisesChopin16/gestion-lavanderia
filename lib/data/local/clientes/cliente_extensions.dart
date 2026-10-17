import 'package:gestion_lavanderia/data/local/app_database.dart';

/// Lo que se calcula a partir de una fila de cliente.
///
/// Va en una extensión y no en un modelo propio: un cliente no tiene más forma
/// que su fila, así que `ClienteEntry` es lo que viaja hasta la interfaz y lo
/// derivado se le cuelga aquí. Es también la herramienta correcta para agregarle
/// comportamiento, porque la fila es código generado y no se puede tocar.
extension ClienteEntryX on ClienteEntry {
  /// Nombre y apellidos unidos, que es como se muestra el cliente en toda
  /// pantalla. Vive en un solo lugar para que la lista de órdenes, el detalle y
  /// el ticket no lo armen cada uno a su manera.
  String get nombreCompleto => '$nombres $apellidos'.trim();
}
