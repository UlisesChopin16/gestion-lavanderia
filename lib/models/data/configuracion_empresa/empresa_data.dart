import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';

part 'empresa_data.freezed.dart';

/// Los datos de la lavandería tal como los edita la pantalla de configuración:
/// la empresa con su dirección anidada.
///
/// En la base son dos tablas y aquí un solo modelo, porque el formulario las
/// guarda en una sola operación y la dirección no tiene sentido por separado.
/// Los valores por omisión son los de un alta —todo vacío y sin id—, así que el
/// formulario siempre trabaja contra un modelo completo y no contra nulos.
///
/// El color viaja como [Color] y no como el entero de la columna: la pantalla
/// lo necesita así y la conversión en los dos sentidos vive en
/// `lib/data/local/configuracion_empresa/empresa_data_mapper.dart`, del lado de
/// los datos, para que este archivo no dependa de drift.
@freezed
sealed class EmpresaData with _$EmpresaData {
  const EmpresaData._();

  const factory EmpresaData({
    /// `0` mientras la configuración no se ha guardado.
    @Default(0) int id,
    @Default('') String nombre,
    @Default('') String telefono,
    @Default('') String correo,
    @Default('') String paginaWeb,

    /// Ruta en disco del logo, o `null` si todavía no se ha elegido uno.
    String? logo,
    @Default(ColoresEmpresa.porOmision) Color color,

    /// Contraseña del modo administrador.
    @Default('') String password,
    @Default(DireccionData()) DireccionData direccion,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) = _EmpresaData;

  /// Si la configuración todavía no existe en la base. Con esto la pantalla
  /// distingue un alta de una edición sin acarrear una bandera aparte, que es
  /// una cosa más que se puede desincronizar de la realidad.
  bool get esNueva => id == 0;

  bool get tieneLogo => logo != null && logo!.isNotEmpty;
}

/// Dirección de la empresa.
///
/// No lleva `empresaId`: la pantalla no puede cambiarlo y el datasource lo
/// escribe con el id de la empresa que acaba de guardar, así que tenerlo aquí
/// sólo permitiría contradecirlo.
@freezed
sealed class DireccionData with _$DireccionData {
  const DireccionData._();

  const factory DireccionData({
    /// `0` mientras la dirección no se ha guardado.
    @Default(0) int id,
    @Default('') String calle,
    @Default('') String numeroExterior,
    String? numeroInterior,
    @Default('') String colonia,

    /// `0` mientras no se ha escrito ninguno.
    @Default(0) int codigoPostal,
    @Default('') String ciudad,
    @Default('') String estado,
  }) = _DireccionData;

  bool get esNueva => id == 0;

  /// El código postal como lo escribe el usuario: vacío mientras no hay nada.
  ///
  /// Sin rellenar con ceros a la izquierda, a propósito: el campo del
  /// formulario se alimenta de aquí y rellenarlo movería el cursor mientras se
  /// escribe.
  String get codigoPostalTexto => codigoPostal == 0 ? '' : '$codigoPostal';

  /// El código postal con sus cinco dígitos, para imprimirlo.
  ///
  /// La columna es entera, así que un código que empieza con cero —01000, que
  /// en México son códigos válidos— se guarda como 1000 y hay que reponerle el
  /// cero al mostrarlo.
  String get codigoPostalCompleto =>
      codigoPostal == 0 ? '' : '$codigoPostal'.padLeft(5, '0');

  /// La dirección en una línea, como la imprime el ticket.
  String get completa {
    final interior = numeroInterior == null || numeroInterior!.trim().isEmpty
        ? ''
        : ' Int. ${numeroInterior!.trim()},';

    return '$calle, No. $numeroExterior,$interior $colonia, $ciudad, '
        '$estado, C.P. $codigoPostalCompleto';
  }
}
