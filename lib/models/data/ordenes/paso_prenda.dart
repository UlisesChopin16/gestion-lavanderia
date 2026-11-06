import 'package:gestion_lavanderia/models/data/ordenes/item_orden_data.dart';

/// En qué punto del camino está una prenda: se recibe y se trabaja, queda
/// lista y sale con el cliente.
///
/// Los pasos van en orden y sólo se avanza: una prenda entregada ya estaba
/// lista, y una lista no vuelve a estar en proceso. Por eso el detalle de la
/// orden ofrece los tres juntos y no dos casillas sueltas —"lista" y
/// "entregar"— que se podían contradecir: elegir uno es decir también los de
/// antes.
enum PasoPrenda {
  enProceso('En proceso'),
  lista('Lista'),
  entregada('Entregar');

  const PasoPrenda(this.etiqueta);

  /// Lo que se lee en el selector. El último paso se nombra como acción
  /// —"Entregar"— porque es lo que se hace al elegirlo: lo ya entregado no se
  /// elige, se lee en el renglón.
  final String etiqueta;

  /// Si este paso ya incluye a [otro]: entregar incluye estar lista.
  bool alcanza(PasoPrenda otro) => index >= otro.index;

  /// El paso en el que la base tiene a [item], antes de marcar nada.
  static PasoPrenda de(ItemOrdenData item) => switch (item) {
    ItemOrdenData(estaEntregado: true) => entregada,
    ItemOrdenData(estaListo: true) => lista,
    _ => enProceso,
  };
}
