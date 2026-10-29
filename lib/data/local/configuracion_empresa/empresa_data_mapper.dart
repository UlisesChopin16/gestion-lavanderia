import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';

/// Traducción entre las filas de la empresa y [EmpresaData].
///
/// Vive del lado de los datos, en extensiones, y no en el modelo: si el mapeo
/// estuviera en [EmpresaData], ese archivo tendría que importar drift y el
/// modelo quedaría amarrado a la base. Las extensiones son además la única
/// forma de agregarle métodos a una fila generada, que no se puede modificar.
extension ConfiguracionEmpresaEntryToData on ConfiguracionEmpresaEntry {
  /// La fila de la empresa con su dirección.
  ///
  /// La dirección llega aparte y puede faltar: son dos tablas, y una empresa
  /// guardada a medias —algo que la transacción de `guardar` ya evita— no debe
  /// impedir abrir la pantalla. En ese caso la dirección queda vacía, lista
  /// para capturarse.
  EmpresaData toData(DireccionEntry? direccion) => EmpresaData(
    id: id,
    nombre: nombre,
    telefono: telefono,
    correo: correo,
    paginaWeb: paginaWeb,
    logo: logo,
    color: Color(color),
    password: password,
    direccion: direccion?.toData() ?? const DireccionData(),
    // Sin la contraseña: no está en la fila. La junta el datasource.
    correoEnvio: CorreoEnvioData(
      servidor: smtpServidor,
      puerto: smtpPuerto,
      usuario: smtpUsuario,
    ),
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion,
  );
}

extension DireccionEntryToData on DireccionEntry {
  DireccionData toData() => DireccionData(
    id: id,
    calle: calle,
    numeroExterior: numeroExterior,
    numeroInterior: numeroInterior,
    colonia: colonia,
    codigoPostal: codigoPostal,
    ciudad: ciudad,
    estado: estado,
  );
}

extension EmpresaDataToCompanion on EmpresaData {
  /// Las columnas que el formulario gobierna.
  ///
  /// Las fechas de auditoría quedan fuera porque las escribe el DAO, y el id
  /// viaja ausente en un alta para que lo asigne SQLite. Un companion con sólo
  /// lo que el formulario cambió es también lo que `updateConfig` espera,
  /// porque lo ausente se queda como está.
  ConfiguracionEmpresaCompanion toCompanion() => ConfiguracionEmpresaCompanion(
    id: esNueva ? const Value.absent() : Value(id),
    nombre: Value(nombre),
    telefono: Value(telefono),
    correo: Value(correo),
    paginaWeb: Value(paginaWeb),
    logo: Value(logo),
    color: Value(color.toARGB32()),
    password: Value(password),
    // La contraseña del correo no se escribe aquí: va cifrada fuera de la
    // base.
    smtpServidor: Value(correoEnvio.servidor.trim()),
    smtpPuerto: Value(correoEnvio.puerto),
    smtpUsuario: Value(correoEnvio.usuario.trim()),
  );

  /// La dirección, sin `empresaId`.
  ///
  /// Lo pone `EmpresaLocalDatasource.guardar` con el id de la empresa que
  /// acaba de escribir: en un alta ese id no existe todavía cuando el
  /// formulario arma el companion.
  DireccionCompanion toDireccionCompanion() => DireccionCompanion(
    id: direccion.esNueva ? const Value.absent() : Value(direccion.id),
    calle: Value(direccion.calle),
    numeroExterior: Value(direccion.numeroExterior),
    numeroInterior: Value(direccion.numeroInterior),
    colonia: Value(direccion.colonia),
    codigoPostal: Value(direccion.codigoPostal),
    ciudad: Value(direccion.ciudad),
    estado: Value(direccion.estado),
  );
}
