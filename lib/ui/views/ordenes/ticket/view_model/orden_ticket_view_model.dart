import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/ticket/correo_ticket.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';
import 'package:gestion_lavanderia/services/ticket/ticket_pdf.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
export 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';

part 'orden_ticket_view_model.freezed.dart';
part 'orden_ticket_view_model.g.dart';

// `makeCollectionsUnmodifiable: false`: freezed 3.0.4 genera un parámetro
// `final` para los campos de lista, que no compila. Ver `MovimientoData`.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class OrdenTicketState with _$OrdenTicketState {
  const OrdenTicketState._();

  const factory OrdenTicketState({
    OrdenDetalleData? orden,

    /// En `null` si la empresa todavía no se configura: el ticket sale igual,
    /// sin encabezado.
    EmpresaData? empresa,

    /// El ticket. En `null` mientras se genera, o si no se pudo.
    Uint8List? pdf,

    /// Las páginas del ticket como imágenes, para la vista previa. Un rollo
    /// es una sola página, pero el rasterizador entrega una lista.
    @Default(<Uint8List>[]) List<Uint8List> paginas,

    @Default(true) bool cargando,
    @Default(false) bool guardando,
    @Default(false) bool enviando,
    @Default('') String mensajeError,

    /// Por qué no salió el último correo. Aparte de [mensajeError] porque se
    /// enseña en el diálogo del envío, que es donde se está mirando y desde
    /// donde se reintenta.
    @Default('') String errorCorreo,
  }) = _OrdenTicketState;

  /// Si ya hay un ticket que descargar o enviar.
  bool get listo => pdf != null && !cargando;

  bool get ocupado => guardando || enviando;

  bool get correoConfigurado => empresa?.correoEnvio.completa ?? false;

  /// A quién se le propone enviar el ticket: el correo del cliente, si lo dio.
  String get correoCliente => orden?.clienteCorreo ?? '';
}

/// El ticket de una orden: se ve, se descarga y se envía por correo.
///
/// Se genera una vez al abrir, y las tres cosas usan ese mismo PDF.
@riverpod
class OrdenTicketViewModel extends _$OrdenTicketViewModel {
  final _ordenes = instance<OrdenesLocalDatasource>();
  final _empresas = instance<EmpresaLocalDatasource>();
  final _ticket = instance<TicketPdf>();
  final _vistaPrevia = instance<VistaPreviaPdf>();
  final _guardado = instance<GuardadoPdf>();
  final _correo = instance<EnvioCorreo>();

  @override
  OrdenTicketState build(int ordenId) {
    Future.microtask(cargar);

    return const OrdenTicketState();
  }

  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    final OrdenDetalleData? orden;
    final EmpresaData? empresa;
    final Uint8List pdf;

    try {
      orden = await _ordenes.detalle(ordenId);

      if (orden == null) {
        if (ref.mounted) {
          state = state.copyWith(
            cargando: false,
            mensajeError: 'La orden ya no existe.',
          );
        }
        return;
      }

      empresa = await _empresas.empresa();
      pdf = await _ticket.generar(orden: orden, empresa: empresa);
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo generar el ticket.');
      return;
    }

    if (!ref.mounted) return;

    state = state.copyWith(orden: orden, empresa: empresa, pdf: pdf);

    // La vista previa va aparte: si el motor que dibuja el PDF falla, el
    // ticket existe igual y se puede descargar o enviar.
    try {
      final paginas = await _vistaPrevia.paginas(pdf);

      if (!ref.mounted) return;

      state = state.copyWith(cargando: false, paginas: paginas);
    } catch (error, stackTrace) {
      _fallar(
        error,
        stackTrace,
        'No se pudo mostrar la vista previa, pero el ticket se puede '
        'descargar y enviar.',
      );
    }
  }

  /// Pide dónde guardar el ticket y lo guarda. Devuelve lo que se hizo, dicho
  /// para el aviso, o `null` si se canceló o falló.
  Future<String?> descargar() async {
    final pdf = state.pdf;
    final orden = state.orden;
    if (pdf == null || orden == null || state.ocupado) return null;

    state = state.copyWith(guardando: true, mensajeError: '');

    try {
      final ruta = await _guardado.guardar(
        pdf,
        nombre: CorreoTicket.nombreArchivo(orden),
      );

      if (ref.mounted) state = state.copyWith(guardando: false);

      return ruta == null ? null : 'El ticket se guardó en $ruta';
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo guardar el ticket.');

      return null;
    }
  }

  /// Envía el ticket a [destinatario] desde la cuenta de la lavandería.
  /// Devuelve lo que se hizo, dicho para el aviso, o `null` si no salió: el
  /// porqué queda en [OrdenTicketState.errorCorreo].
  Future<String?> enviar(String destinatario) async {
    final pdf = state.pdf;
    final orden = state.orden;
    final empresa = state.empresa;
    final para = destinatario.trim();
    if (pdf == null || orden == null || state.ocupado) return null;

    if (empresa == null || !state.correoConfigurado) {
      state = state.copyWith(
        errorCorreo: 'Falta configurar la cuenta de correo de la lavandería.',
      );
      return null;
    }

    if (!para.isEmail) {
      state = state.copyWith(errorCorreo: 'El correo no es válido.');
      return null;
    }

    state = state.copyWith(enviando: true, errorCorreo: '');

    try {
      await _correo.enviar(
        cuenta: empresa.correoEnvio,
        remitente: empresa.nombre,
        destinatario: para,
        asunto: CorreoTicket.asunto(orden, empresa),
        html: CorreoTicket.html(orden, empresa),
        adjunto: pdf,
        nombreAdjunto: CorreoTicket.nombreArchivo(orden),
      );

      if (ref.mounted) state = state.copyWith(enviando: false);

      return 'Se envió el ticket de la orden ${orden.folio} a $para.';
    } catch (error, stackTrace) {
      debugPrint('No se pudo enviar el ticket.\n$error\n$stackTrace');

      if (ref.mounted) {
        state = state.copyWith(
          enviando: false,
          errorCorreo: error is EnvioCorreoException
              ? error.mensaje
              : 'No se pudo enviar el correo.',
        );
      }

      return null;
    }
  }

  /// Borra el error del correo: al volver a abrir el envío, el de la vez
  /// anterior ya no viene al caso.
  void olvidarErrorCorreo() {
    if (state.errorCorreo.isEmpty) return;

    state = state.copyWith(errorCorreo: '');
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
