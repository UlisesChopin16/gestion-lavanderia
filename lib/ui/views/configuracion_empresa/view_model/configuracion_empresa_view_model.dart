import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/exceptions/s_q_l_exception.dart';
import 'package:gestion_lavanderia/datasource/local/datasources.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/logo_storage.dart';
import 'package:gestion_lavanderia/validations/empresa_validation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
export 'package:gestion_lavanderia/validations/empresa_validation.dart';

part 'configuracion_empresa_view_model.freezed.dart';
part 'configuracion_empresa_view_model.g.dart';

/// En qué terminó un intento de guardar.
///
/// El resultado se devuelve a quien pulsó el botón en lugar de dejarlo en el
/// estado: el aviso pertenece a esa pulsación, y así la pantalla no necesita
/// escuchar un mensaje que, si se repite igual dos veces, no vuelve a notificar.
enum ResultadoGuardado { guardado, camposInvalidos, error }

@freezed
sealed class ConfiguracionEmpresaState with _$ConfiguracionEmpresaState {
  const ConfiguracionEmpresaState._();

  const factory ConfiguracionEmpresaState({
    @Default(EmpresaData()) EmpresaData empresa,

    /// Si hay una lectura o un guardado en curso.
    @Default(true) bool cargando,

    /// Si el formulario acepta cambios.
    ///
    /// Una configuración que ya existe arranca protegida y se desbloquea con la
    /// contraseña; un alta nace editable, porque todavía no hay contraseña con
    /// la que pedir permiso.
    @Default(true) bool editable,
    @Default(false) bool passwordVisible,

    /// Los campos que están mal, con el motivo de cada uno.
    @Default(ErroresEmpresa.ninguno()) ErroresEmpresa errores,

    /// Lo último que falló, para mostrarlo en la pantalla. Vacío si no hay nada.
    @Default('') String mensajeError,
  }) = _ConfiguracionEmpresaState;

  /// Si la configuración todavía no existe en la base.
  bool get esAlta => empresa.esNueva;

  /// Por qué está mal [campo], o `null` si está bien.
  String? errorDe(CampoEmpresa campo) => errores[campo];
}

/// El formulario de configuración de la empresa.
@riverpod
class ConfiguracionEmpresaViewModel extends _$ConfiguracionEmpresaViewModel {
  // Se resuelven al construir el notificador, no en cada método: get_it
  // devuelve siempre la misma instancia, así que buscarla de nuevo cada vez no
  // cambiaría nada y escondería de quién depende esta pantalla.
  final _empresas = instance<EmpresaLocalDatasource>();
  final _logos = instance<LogoStorage>();

  @override
  ConfiguracionEmpresaState build() {
    // La lectura arranca aquí, en una microtarea —`build` tiene que devolver el
    // estado inicial sin esperar—, y no desde la pantalla: así el formulario no
    // depende de que alguien se acuerde de llamarla, y al invalidar el provider
    // se vuelve a leer la base.
    Future.microtask(cargar);

    return const ConfiguracionEmpresaState();
  }

  /// Trae la configuración guardada; si no hay ninguna, deja el formulario en
  /// blanco listo para el alta.
  Future<void> cargar() async {
    state = state.copyWith(cargando: true, mensajeError: '');

    try {
      final empresa = await _empresas.empresa();

      if (!ref.mounted) return;

      state = state.copyWith(
        cargando: false,
        empresa: empresa ?? const EmpresaData(),
        editable: empresa == null,
        passwordVisible: false,
        errores: const ErroresEmpresa.ninguno(),
      );
    } catch (error, stackTrace) {
      _fallar(
        error,
        stackTrace,
        'No se pudieron leer los datos de la empresa.',
      );
    }
  }

  void cambiarNombre(String nombre) =>
      _editar(state.empresa.copyWith(nombre: nombre));

  void cambiarTelefono(String telefono) =>
      _editar(state.empresa.copyWith(telefono: telefono));

  void cambiarCorreo(String correo) =>
      _editar(state.empresa.copyWith(correo: correo));

  void cambiarPaginaWeb(String paginaWeb) =>
      _editar(state.empresa.copyWith(paginaWeb: paginaWeb));

  void cambiarPassword(String password) =>
      _editar(state.empresa.copyWith(password: password));

  void cambiarColor(Color color) =>
      _editar(state.empresa.copyWith(color: color));

  void cambiarDireccion(DireccionData direccion) =>
      _editar(state.empresa.copyWith(direccion: direccion));

  /// Pide una imagen y la deja guardada como logo.
  ///
  /// Cerrar el diálogo sin elegir no es un error ni borra el logo actual.
  Future<void> cambiarLogo() async {
    try {
      final ruta = await _logos.elegirLogo(rutaAnterior: state.empresa.logo);

      if (!ref.mounted || ruta == null) return;

      _editar(state.empresa.copyWith(logo: ruta));
    } catch (error, stackTrace) {
      _fallar(error, stackTrace, 'No se pudo guardar el logo.');
    }
  }

  void alternarPasswordVisible() {
    // En sólo lectura la contraseña no se descubre: la pantalla puede quedar a
    // la vista de cualquiera.
    if (!state.editable) return;

    state = state.copyWith(passwordVisible: !state.passwordVisible);
  }

  /// Valida y guarda. Al terminar, el formulario vuelve a quedar protegido.
  Future<ResultadoGuardado> guardar() async {
    final errores = validarEmpresa(state.empresa);

    if (errores.hay) {
      state = state.copyWith(
        errores: errores,
        mensajeError: 'Revisa los campos marcados en rojo.',
      );

      return ResultadoGuardado.camposInvalidos;
    }

    state = state.copyWith(
      cargando: true,
      mensajeError: '',
      errores: const ErroresEmpresa.ninguno(),
    );

    try {
      final empresa = state.empresa;

      await _empresas.guardar(empresa);

      if (!ref.mounted) return ResultadoGuardado.guardado;

      // Se vuelve a leer para quedarse con los ids y las fechas que escribió la
      // base: sin eso un alta seguiría pareciendo nueva y el siguiente guardado
      // insertaría un segundo registro.
      await cargar();

      return ResultadoGuardado.guardado;
    } catch (error, stackTrace) {
      _fallar(
        error,
        stackTrace,
        'No se pudieron guardar los datos de la empresa.',
      );

      return ResultadoGuardado.error;
    }
  }

  /// Habilita la edición si [password] es la contraseña guardada.
  bool habilitarEdicion(String password) {
    if (state.empresa.password != password) return false;

    state = state.copyWith(editable: true, mensajeError: '');

    return true;
  }

  /// Descarta los cambios sin guardar y vuelve a proteger el formulario.
  Future<void> cancelarEdicion() => cargar();

  /// Aplica un cambio del formulario.
  void _editar(EmpresaData empresa) {
    state = state.copyWith(
      empresa: empresa,
      errores: _erroresVigentes(empresa),
    );
  }

  /// Los errores que siguen vigentes después de un cambio.
  ///
  /// Sólo se conservan los que ya estaban marcados: corregir un campo le quita
  /// el rojo en cuanto queda bien, y un campo que nunca se intentó guardar no
  /// se marca mientras se escribe —nadie quiere ver "el correo no es válido"
  /// tras teclear la primera letra—.
  ErroresEmpresa _erroresVigentes(EmpresaData empresa) {
    if (!state.errores.hay) return const ErroresEmpresa.ninguno();

    return validarEmpresa(empresa).soloDe(state.errores.campos);
  }

  /// Deja el error a la vista y lo manda a la consola.
  ///
  /// Al usuario se le dice qué no se pudo hacer; el detalle técnico va al log,
  /// porque un `toString` de una excepción de SQLite no le dice nada a quien
  /// atiende el mostrador.
  void _fallar(Object error, StackTrace stackTrace, String mensaje) {
    debugPrint('$mensaje\n$error\n$stackTrace');

    if (!ref.mounted) return;

    final detalle = error is SQLException ? error.message : mensaje;

    state = state.copyWith(cargando: false, mensajeError: detalle);
  }
}
