import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
import 'package:gestion_lavanderia/models/data/ordenes/paso_prenda.dart';
import 'package:gestion_lavanderia/models/data/shared/filas.dart';
import 'package:gestion_lavanderia/services/avisos/aviso_ropa_lista.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
export 'package:gestion_lavanderia/models/data/ordenes/paso_prenda.dart';
export 'package:gestion_lavanderia/models/data/shared/filas.dart';

part 'orden_detalle_view_model.freezed.dart';
part 'orden_detalle_view_model.g.dart';

/// Lo que se registró en el detalle: el aviso para el listado y si con ese
/// cobro la orden quedó pagada, que es cuando el listado vuelve a enseñar el
/// ticket.
typedef MovimientoRegistrado = ({String mensaje, bool saldoLaOrden});

@freezed
sealed class OrdenDetalleState with _$OrdenDetalleState {
  const OrdenDetalleState._();

  const factory OrdenDetalleState({
    /// La orden tal como está en la base. En `null` mientras se lee, o si ya
    /// no existe.
    OrdenDetalleData? orden,

    /// Los renglones pendientes que se marcaron para entregar ahora.
    @Default(Filas<int>()) Filas<int> aEntregar,

    /// Los renglones que se marcaron como listos para recogerse. Incluye los
    /// que se van a entregar: lo que sale ya estaba listo.
    @Default(Filas<int>()) Filas<int> aMarcarListos,

    /// La lavandería, para el aviso por correo. Sólo se lee si el aviso está
    /// encendido.
    EmpresaData? empresa,

    /// Si al marcar ropa como lista se le avisará al cliente por correo: el
    /// aviso está encendido, la lavandería tiene su cuenta y el cliente su
    /// correo.
    @Default(false) bool avisaAlCliente,

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

  bool seMarcaLista(ItemOrdenData item) => aMarcarListos.contains(item.id);

  /// El paso en el que quedará [item] al guardar: el de la base, o el que se
  /// le eligió ahora.
  PasoPrenda pasoDe(ItemOrdenData item) {
    if (item.estaEntregado || seEntrega(item)) return PasoPrenda.entregada;
    if (item.estaListo || seMarcaLista(item)) return PasoPrenda.lista;

    return PasoPrenda.enProceso;
  }

  /// Si a [item] se le eligió un paso que todavía no está guardado.
  bool cambiaDePaso(ItemOrdenData item) => pasoDe(item) != PasoPrenda.de(item);

  /// Si alguna prenda pendiente puede avanzar hasta [paso].
  bool puedeLlevarTodoA(PasoPrenda paso) =>
      pendientes.any((item) => !pasoDe(item).alcanza(paso));

  /// Si se eligió algo para alguna prenda, que es cuando tiene sentido
  /// deshacerlo.
  bool get hayPasosElegidos => aEntregar.isNotEmpty || aMarcarListos.isNotEmpty;

  /// Lo que se marcará como listo al guardar. Lo que además se entrega no
  /// cuenta: al salir se marca listo solo.
  List<int> get listosNuevos => [
    for (final id in aMarcarListos)
      if (!aEntregar.contains(id)) id,
  ];

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
  CobroEnEfectivo get efectivo =>
      CobroEnEfectivo(metodoPago: metodoPago, abono: abono, recibido: recibido);

  /// Lo que hay que devolverle al cliente cuando paga en efectivo.
  double get cambio => efectivo.cambio;

  /// Si el efectivo que entrega el cliente no alcanza para lo que dice que
  /// paga.
  bool get recibidoInsuficiente => efectivo.insuficiente;

  bool get hayMovimiento =>
      abono > margenSaldo || aEntregar.isNotEmpty || listosNuevos.isNotEmpty;

  /// Si al guardar hay que pedir confirmación: se le enviará un correo al
  /// cliente, y eso no se puede deshacer.
  bool get confirmaAviso => avisaAlCliente && listosNuevos.isNotEmpty;

  bool get puedeRegistrar =>
      admiteMovimientos &&
      hayMovimiento &&
      !faltaPagarParaEntregarTodo &&
      !recibidoInsuficiente &&
      !guardando;

  /// Lo que dice el botón: lo que va a pasar al pulsarlo, con su importe.
  /// `Cobrar 50.00, entregar y marcar 2 listos`.
  String get etiquetaAccion {
    final cobra = abono > margenSaldo;
    final entregadas = aEntregar.length;
    final listos = listosNuevos.length;

    final partes = [
      if (cobra) 'cobrar ${abono.toStringAsFixed(2)}',
      if (entregadas > 0)
        cobra ? 'entregar' : 'entregar ${_conceptos(entregadas)}',
      if (listos > 0)
        cobra || entregadas > 0
            ? 'marcar ${listos == 1 ? '1 listo' : '$listos listos'}'
            : 'marcar ${_conceptos(listos)} como '
                  '${listos == 1 ? 'listo' : 'listos'}',
    ];
    if (partes.isEmpty) return 'Registrar';

    final frase = partes.length == 1
        ? partes.single
        : '${partes.take(partes.length - 1).join(', ')} y ${partes.last}';

    return frase[0].toUpperCase() + frase.substring(1);
  }
}

String _conceptos(int cuantos) =>
    cuantos == 1 ? '1 concepto' : '$cuantos conceptos';

/// El detalle de una orden: se mira, se cobra, se marca la ropa que ya está
/// lista y se entrega.
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
  final _empresas = instance<EmpresaLocalDatasource>();
  final _aviso = instance<AvisoRopaLista>();

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

      // La lavandería sólo hace falta para el aviso: apagado, no se lee —ni
      // su contraseña, que vive en el almacén cifrado—.
      final empresa = _aviso.habilitado ? await _empresas.empresa() : null;

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        orden: orden,
        empresa: empresa,
        avisaAlCliente: _aviso.avisaA(orden, empresa),
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo leer la orden.');
    }
  }

  /// Lleva una prenda pendiente hasta [paso].
  ///
  /// Entregar la deja también lista: lo que sale del mostrador ya estaba
  /// terminado, y así lo dice el renglón antes de guardar. Lo que la base ya
  /// tiene no se deshace —una prenda lista no vuelve a estar en proceso—, así
  /// que un paso anterior al guardado la deja en el guardado.
  void cambiarPaso(ItemOrdenData item, PasoPrenda paso) {
    if (!state.admiteMovimientos || item.estaEntregado) return;

    state = state.copyWith(
      aEntregar: _con(state.aEntregar, item, paso == PasoPrenda.entregada),
      aMarcarListos: _con(
        state.aMarcarListos,
        item,
        !item.estaListo && paso.alcanza(PasoPrenda.lista),
      ),
    );
  }

  /// Lleva toda la ropa pendiente hasta [paso], sin regresar ninguna: con
  /// "Todo listo", la que ya se iba a entregar se sigue entregando.
  void llevarTodoA(PasoPrenda paso) {
    if (!state.admiteMovimientos) return;

    for (final item in state.pendientes) {
      if (!state.pasoDe(item).alcanza(paso)) cambiarPaso(item, paso);
    }
  }

  /// Deja la ropa como está en la base: nada por entregar ni por marcar.
  void deshacerPasos() {
    state = state.copyWith(
      aEntregar: const Filas(),
      aMarcarListos: const Filas(),
    );
  }

  /// [ids] con [item] dentro o fuera.
  Filas<int> _con(Filas<int> ids, ItemOrdenData item, bool dentro) {
    if (ids.contains(item.id) == dentro) return ids;

    return Filas(
      dentro ? [...ids, item.id] : ids.where((id) => id != item.id).toList(),
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

  /// Escribe el movimiento. Devuelve lo que se registró, o `null` si no se
  /// pudo.
  ///
  /// La orden queda saldada por este movimiento sólo si en él se cobró algo:
  /// entregar la ropa de una orden que ya estaba pagada no la salda otra vez.
  Future<MovimientoRegistrado?> registrar() async {
    final orden = state.orden;
    if (orden == null || !state.puedeRegistrar) return null;

    // Lo que se va a registrar se toma antes de escribir: después el estado
    // ya trae la orden nueva, con el saldo y la ropa recalculados.
    final abono = state.abono > OrdenDetalleState.margenSaldo
        ? state.abono
        : 0.0;
    final entregadas = state.aEntregar.length;
    final listos = state.listosNuevos;
    final recibido = state.efectivo.aGuardar;
    final empresa = state.empresa;
    final avisar = state.confirmaAviso;

    state = state.copyWith(guardando: true, mensajeError: '');

    try {
      // Sólo marcar ropa como lista no es un movimiento: no cobra ni saca
      // nada, y no debe dejar un renglón vacío en el historial.
      final actualizada = abono == 0 && entregadas == 0
          ? await _ordenes.marcarListos(ordenId: ordenId, itemIds: listos)
          : await _ordenes.registrarMovimiento(
              ordenId: ordenId,
              monto: abono,
              // Una entrega sin cobro conserva el método del último
              // movimiento: el listado enseña ése, y no tendría por qué
              // cambiar porque alguien pasó a recoger ropa.
              metodoPago: abono > 0
                  ? state.metodoPago
                  : orden.ultimoMovimiento?.metodoPago ?? state.metodoPago,
              recibido: recibido,
              itemsAEntregar: state.aEntregar,
              itemsListos: listos,
            );

      // El aviso sale después de guardar, y fuera de la transacción: si el
      // correo falla, lo marcado ya quedó y sólo se dice que no se avisó.
      final aviso = avisar && empresa != null
          ? await _avisar(actualizada, empresa)
          : '';

      if (ref.mounted) {
        state = state.copyWith(guardando: false, orden: actualizada);
      }

      return (
        mensaje:
            _mensaje(
              folio: orden.folio,
              abono: abono,
              entregadas: entregadas,
              listos: listos.length,
              cerrada: actualizada.estatus == EstatusOrdenType.cerrada,
            ) +
            aviso,
        saldoLaOrden:
            abono > 0 && actualizada.restante <= OrdenDetalleState.margenSaldo,
      );
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo registrar el movimiento.');

      return null;
    }
  }

  /// Envía el aviso de ropa lista y devuelve cómo le fue, para sumarlo al
  /// mensaje.
  Future<String> _avisar(OrdenDetalleData orden, EmpresaData empresa) async {
    try {
      await _aviso.enviar(orden, empresa);

      return ' Se le avisó por correo a ${orden.clienteCorreo.trim()}.';
    } on EnvioCorreoException catch (error) {
      debugPrint('No se pudo enviar el aviso de ropa lista.\n$error');

      return ' No se pudo avisar por correo: ${error.mensaje}';
    }
  }

  String _mensaje({
    required String folio,
    required double abono,
    required int entregadas,
    required int listos,
    required bool cerrada,
  }) {
    final partes = [
      if (abono > 0) 'el pago de ${abono.toStringAsFixed(2)}',
      if (entregadas > 0) 'la entrega de ${_conceptos(entregadas)}',
    ];
    final marcados = listos == 1
        ? 'marcó 1 concepto como listo'
        : 'marcaron $listos conceptos como listos';
    final cierre = cerrada ? ' La orden quedó pagada y entregada.' : '';

    if (partes.isEmpty) return 'Se $marcados en la orden $folio.';

    final tambien = listos > 0 ? ' También se $marcados.' : '';

    return 'Se registró ${partes.join(' y ')} de la orden $folio.'
        '$cierre$tambien';
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
