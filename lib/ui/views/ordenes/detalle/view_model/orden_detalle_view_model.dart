import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';

part 'orden_detalle_view_model.freezed.dart';
part 'orden_detalle_view_model.g.dart';

@freezed
sealed class OrdenDetalleState with _$OrdenDetalleState {
  const OrdenDetalleState._();

  const factory OrdenDetalleState({
    /// La orden tal como está en la base. En `null` mientras se lee, o si ya
    /// no existe.
    OrdenDetalleData? orden,

    /// Los renglones pendientes que se marcaron para entregar ahora.
    @Default(Filas<int>()) Filas<int> aEntregar,

    @Default(MetodoPagoType.efectivo) MetodoPagoType metodoPago,

    /// Lo que se cobra en este movimiento.
    @Default(0.0) double abono,

    /// Con cuánto paga el cliente cuando paga en efectivo. Puede ser más que
    /// [abono] —da quinientos para pagar trescientos— y se guarda en el
    /// movimiento, junto al cobro.
    @Default(0.0) double recibido,

    @Default(true) bool cargando,
    @Default(false) bool guardando,
    @Default('') String mensajeError,
  }) = _OrdenDetalleState;

  /// Medio centavo: el mismo margen con el que la base da una orden por
  /// saldada, porque los importes son `double` y un cero puede quedar en
  /// 0.0000001 después de varias restas.
  static const double margenSaldo = 0.005;

  double get total => orden?.total ?? 0;

  double get restante => orden?.restante ?? 0;

  double get pagado => total - restante;

  bool get pagada => restante <= margenSaldo;

  List<ItemOrdenData> get pendientes => orden?.pendientes ?? const [];

  bool get todoEntregado => orden?.todoEntregado ?? false;

  /// Una orden cerrada o cancelada ya no se mueve: la base rechaza cualquier
  /// cobro o entrega sobre ella.
  bool get admiteMovimientos => switch (orden?.estatus) {
    null || EstatusOrdenType.cerrada || EstatusOrdenType.cancelada => false,
    _ => true,
  };

  /// Si no queda nada que hacer con la orden y sólo se enseña cómo quedó.
  ///
  /// Pagada y entregada es lo que la base llama cerrada, pero se pregunta por
  /// las dos cosas y no sólo por el estatus: es lo que se le promete a quien
  /// la mira, y no depende de que el estatus se haya recalculado.
  bool get soloResumen => !admiteMovimientos || (pagada && todoEntregado);

  bool seEntrega(ItemOrdenData item) => aEntregar.contains(item.id);

  /// Si con lo marcado sale toda la ropa que quedaba.
  bool get entregaTodo => pendientes.isNotEmpty && pendientes.every(seEntrega);

  /// Lo que quedará a deber después de este movimiento.
  double get restanteTras => restante - abono;

  /// La regla de la entrega: la ropa puede salir por partes sin pagar, pero
  /// la última prenda no sale si la orden no queda pagada. Se cuenta lo que
  /// se cobra en el mismo movimiento: pagar y llevárselo todo es una sola
  /// operación en el mostrador.
  bool get faltaPagarParaEntregarTodo =>
      entregaTodo && restanteTras > margenSaldo;

  /// Las cuentas del cobro cuando es en efectivo. Las mismas que las del
  /// adelanto del alta: viven en [CobroEnEfectivo] para que las dos pantallas
  /// no puedan decidir distinto.
  CobroEnEfectivo get efectivo => CobroEnEfectivo(
    metodoPago: metodoPago,
    abono: abono,
    recibido: recibido,
  );

  /// Lo que hay que devolverle al cliente cuando paga en efectivo.
  double get cambio => efectivo.cambio;

  /// Si el efectivo que entrega el cliente no alcanza para lo que dice que
  /// paga.
  bool get recibidoInsuficiente => efectivo.insuficiente;

  bool get hayMovimiento => abono > margenSaldo || aEntregar.isNotEmpty;

  bool get puedeRegistrar =>
      admiteMovimientos &&
      hayMovimiento &&
      !faltaPagarParaEntregarTodo &&
      !recibidoInsuficiente &&
      !guardando;

  /// Lo que dice el botón: lo que va a pasar al pulsarlo, con su importe.
  String get etiquetaAccion {
    final cobra = abono > margenSaldo;
    final entregadas = aEntregar.length;

    if (cobra && entregadas > 0) {
      return 'Cobrar ${abono.toStringAsFixed(2)} y entregar';
    }
    if (cobra) return 'Cobrar ${abono.toStringAsFixed(2)}';
    if (entregadas > 0) return 'Entregar ${_conceptos(entregadas)}';

    return 'Registrar';
  }
}

String _conceptos(int cuantos) =>
    cuantos == 1 ? '1 concepto' : '$cuantos conceptos';

/// El detalle de una orden: se mira, se cobra y se entrega la ropa.
///
/// Cobrar y entregar son un solo movimiento —`registrarMovimiento`, que es
/// atómico—, así que la pantalla junta las dos cosas y las escribe de una
/// vez: el cliente que paga lo que falta y se lleva todo hace una sola
/// operación, no dos.
///
/// Es una familia por orden y se desecha al cerrar el diálogo, así que cada
/// vez que se abre empieza leyendo la orden tal como está en la base.
@riverpod
class OrdenDetalleViewModel extends _$OrdenDetalleViewModel {
  final _ordenes = instance<OrdenesLocalDatasource>();

  @override
  OrdenDetalleState build(int ordenId) {
    Future.microtask(cargar);

    return const OrdenDetalleState();
  }

  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final orden = await _ordenes.detalle(ordenId);

      if (!ref.mounted) return;

      if (orden == null) {
        state = state.copyWith(
          cargando: false,
          mensajeError: 'La orden ya no existe.',
        );
        return;
      }

      state = state.copyWith(cargando: false, orden: orden);
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo leer la orden.');
    }
  }

  /// Marca o desmarca un renglón para entregarlo. Uno ya entregado no se
  /// toca: su entrega quedó fechada en el historial.
  void alternarEntrega(ItemOrdenData item) {
    if (!state.admiteMovimientos || item.estaEntregado) return;

    final ids = state.aEntregar.toList();
    if (!ids.remove(item.id)) ids.add(item.id);

    state = state.copyWith(aEntregar: Filas(ids));
  }

  /// Marca toda la ropa pendiente, o ninguna.
  void marcarTodo(bool todo) {
    if (!state.admiteMovimientos) return;

    state = state.copyWith(
      aEntregar: Filas([
        if (todo)
          for (final item in state.pendientes) item.id,
      ]),
    );
  }

  /// El efectivo recibido sólo existe en efectivo: con tarjeta no hay cambio
  /// que sacar, y un número de antes se quedaría bloqueando el botón.
  void elegirMetodoPago(MetodoPagoType metodoPago) {
    state = state.copyWith(
      metodoPago: metodoPago,
      recibido: metodoPago == MetodoPagoType.efectivo ? state.recibido : 0,
    );
  }

  /// Lo que se cobra, entre nada y lo que queda a deber: la base rechaza un
  /// abono mayor que el saldo.
  void cambiarAbono(double abono) {
    state = state.copyWith(abono: abono.clamp(0, state.restante));
  }

  /// El atajo de "paga lo que falta".
  void abonarTodo() => cambiarAbono(state.restante);

  void cambiarRecibido(double recibido) {
    state = state.copyWith(recibido: recibido < 0 ? 0 : recibido);
  }

  /// Escribe el movimiento. Devuelve lo que se registró, dicho para el aviso
  /// de la pantalla, o `null` si no se pudo.
  Future<String?> registrar() async {
    final orden = state.orden;
    if (orden == null || !state.puedeRegistrar) return null;

    // Lo que se va a registrar se toma antes de escribir: después el estado
    // ya trae la orden nueva, con el saldo y la ropa recalculados.
    final abono = state.abono > OrdenDetalleState.margenSaldo
        ? state.abono
        : 0.0;
    final entregadas = state.aEntregar.length;
    final recibido = state.efectivo.aGuardar;

    state = state.copyWith(guardando: true, mensajeError: '');

    try {
      final actualizada = await _ordenes.registrarMovimiento(
        ordenId: ordenId,
        monto: abono,
        // Una entrega sin cobro conserva el método del último movimiento: el
        // listado enseña ése, y no tendría por qué cambiar porque alguien
        // pasó a recoger ropa.
        metodoPago: abono > 0
            ? state.metodoPago
            : orden.ultimoMovimiento?.metodoPago ?? state.metodoPago,
        recibido: recibido,
        itemsAEntregar: state.aEntregar,
      );

      if (ref.mounted) {
        state = state.copyWith(guardando: false, orden: actualizada);
      }

      return _mensaje(
        folio: orden.folio,
        abono: abono,
        entregadas: entregadas,
        cerrada: actualizada.estatus == EstatusOrdenType.cerrada,
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo registrar el movimiento.');

      return null;
    }
  }

  String _mensaje({
    required String folio,
    required double abono,
    required int entregadas,
    required bool cerrada,
  }) {
    final partes = [
      if (abono > 0) 'el pago de ${abono.toStringAsFixed(2)}',
      if (entregadas > 0) 'la entrega de ${_conceptos(entregadas)}',
    ];
    final cierre = cerrada ? ' La orden quedó pagada y entregada.' : '';

    return 'Se registró ${partes.join(' y ')} de la orden $folio.$cierre';
  }

  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    state = state.copyWith(
      cargando: false,
      guardando: false,
      mensajeError: error is SQLException ? error.message : mensaje,
    );
  }
}
