import 'package:freezed_annotation/freezed_annotation.dart';

part 'cliente_data.freezed.dart';

/// Un cliente, tal como lo usan las pantallas.
///
/// No sabe nada de drift: la conversión en los dos sentidos vive en
/// `lib/data/local/clientes/cliente_data_mapper.dart`, del lado de los datos.
/// Así la interfaz habla de clientes y no de filas, y cambiar la tabla —una
/// columna nueva, un converter— no obliga a tocar lo que se dibuja.
///
/// Lo derivado vive aquí, con el dato del que sale: [nombreCompleto] estaba
/// antes en una extensión sobre la fila generada, que era el único sitio donde
/// se le podía colgar comportamiento a algo que no se puede modificar.
@freezed
sealed class ClienteData with _$ClienteData {
  const ClienteData._();

  const factory ClienteData({
    /// `0` mientras el cliente no se ha guardado.
    @Default(0) int id,
    @Default('') String nombres,
    @Default('') String apellidos,

    /// Opcional: un cliente de mostrador puede no dejar correo.
    @Default('') String correo,
    @Default('') String telefono,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    DateTime? fechaEliminacion,
  }) = _ClienteData;

  bool get esNuevo => id == 0;

  /// Nombre y apellidos unidos, que es como se muestra el cliente en toda
  /// pantalla. Vive en un solo lugar para que la lista de órdenes, el detalle
  /// y el ticket no lo armen cada uno a su manera.
  String get nombreCompleto => '$nombres $apellidos'.trim();
}
