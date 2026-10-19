import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/clientes/cliente_data_mapper.dart';
import 'package:gestion_lavanderia/data/local/ordenes/history_con_items_entry.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_con_precio_entry.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_con_detalles_entry.dart';
import 'package:gestion_lavanderia/data/local/precios/precio_data_mapper.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_listado_data.dart';

/// Traducción entre las filas de órdenes y los modelos que consume la interfaz.
///
/// Igual que en los precios, el mapeo vive en extensiones del lado de los datos
/// para que los modelos no importen drift.

extension OrdenConDetallesToData on OrdenConDetallesEntry {
  OrdenListadoData toData() => OrdenListadoData(
    id: orden.id,
    folio: orden.folio,
    clienteId: orden.clienteId,
    cliente: cliente.toData().nombreCompleto,
    descripcion: orden.descripcion,
    estatus: orden.estatus,
    total: orden.total,
    restante: orden.restante,
    metodoPago: detalles.metodoPago,
    fechaCreacion: orden.fechaCreacion,
    fechaCierre: orden.fechaCierre,
    ultimaInteraccion: detalles.fecha,
  );
}

extension OrdenesConDetallesToData on Iterable<OrdenConDetallesEntry> {
  List<OrdenListadoData> toData() => map((fila) => fila.toData()).toList();
}

extension ItemConPrecioToData on ItemConPrecioEntry {
  ItemOrdenData toData() => ItemOrdenData(
    id: item.id,
    ordenId: item.ordenId,
    precio: precio.toData(),
    cantidad: item.cantidad,
    importe: item.importe,
    estaEntregado: item.estaEntregado,
    fechaEntrega: item.fechaEntrega,
    fechaEntregado: item.fechaEntregado,
    ordenHistoryId: item.ordenHistoryId,
  );
}

extension ItemsConPrecioToData on Iterable<ItemConPrecioEntry> {
  List<ItemOrdenData> toData() => map((fila) => fila.toData()).toList();
}

extension HistoryConItemsToData on HistoryConItemsEntry {
  MovimientoData toData() => MovimientoData(
    id: movimiento.id,
    ordenId: movimiento.ordenId,
    monto: movimiento.monto,
    restante: movimiento.restante,
    metodoPago: movimiento.metodoPago,
    fecha: movimiento.fecha,
    entregados: entregados.toData(),
  );
}

extension HistorialConItemsToData on Iterable<HistoryConItemsEntry> {
  List<MovimientoData> toData() => map((fila) => fila.toData()).toList();
}

extension OrdenServicioToDetalle on OrdenServicioEntry {
  /// Arma el detalle de la orden con las piezas que el datasource ya leyó.
  ///
  /// Las recibe en lugar de consultarlas: un mapeo que lanzara consultas
  /// escondería el número de viajes a la base detrás de lo que parece una
  /// conversión.
  OrdenDetalleData toDetalle({
    required ClienteEntry cliente,
    required Iterable<ItemConPrecioEntry> items,
    required Iterable<HistoryConItemsEntry> historial,
  }) {
    return OrdenDetalleData(
      id: id,
      folio: folio,
      clienteId: clienteId,
      cliente: cliente.toData().nombreCompleto,
      clienteTelefono: cliente.telefono,
      clienteCorreo: cliente.correo,
      descripcion: descripcion,
      estatus: estatus,
      total: total,
      restante: restante,
      fechaCreacion: fechaCreacion,
      fechaCierre: fechaCierre,
      items: items.toData(),
      historial: historial.toData(),
    );
  }
}

extension ItemOrdenDataToCompanion on ItemOrdenData {
  /// El renglón como escritura.
  ///
  /// [ordenId] se puede pasar aparte porque los renglones de una orden nueva se
  /// arman antes de que la orden exista, así que todavía no tienen a qué orden
  /// pertenecen. Las columnas de la entrega van incluidas, pero quien entrega
  /// ropa usa `ItemServicioOrdenDao.entregarItems`, que las escribe las tres
  /// juntas y no deja que se desalineen.
  ItemServicioOrdenCompanion toCompanion({int? ordenId}) {
    return ItemServicioOrdenCompanion(
      id: esNuevo ? const Value.absent() : Value(id),
      ordenId: Value(ordenId ?? this.ordenId),
      precioConceptoId: Value(precio.id),
      cantidad: Value(cantidad),
      importe: Value(importe),
      estaEntregado: Value(estaEntregado),
      fechaEntrega: Value(fechaEntrega),
      fechaEntregado: Value(fechaEntregado),
      ordenHistoryId: Value(ordenHistoryId),
    );
  }
}

extension MovimientoDataToCompanion on MovimientoData {
  /// El movimiento como escritura. Los items entregados no viajan aquí: cada
  /// item guarda a qué movimiento pertenece, así que se escriben del otro lado
  /// de la relación.
  OrdenHistoryCompanion toCompanion({int? ordenId}) {
    return OrdenHistoryCompanion(
      id: id == 0 ? const Value.absent() : Value(id),
      ordenId: Value(ordenId ?? this.ordenId),
      monto: Value(monto),
      restante: Value(restante),
      metodoPago: Value(metodoPago),
      fecha: Value(fecha),
    );
  }
}

extension OrdenDetalleDataToCompanion on OrdenDetalleData {
  /// La orden como escritura, sin su ropa ni su historial: son tablas aparte y
  /// las coordina `OrdenesLocalDatasource` dentro de una transacción.
  OrdenServicioCompanion toCompanion() {
    return OrdenServicioCompanion(
      id: id == 0 ? const Value.absent() : Value(id),
      clienteId: Value(clienteId),
      descripcion: Value(descripcion),
      estatus: Value(estatus),
      total: Value(total),
      restante: Value(restante),
      fechaCierre: Value(fechaCierre),
    );
  }
}
