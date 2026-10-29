import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/configuracion_empresa_dao.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/direccion_dao.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/empresa_data_mapper.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/services/secretos_correo.dart';

export 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';

/// Los datos de la lavandería: su configuración y su dirección.
///
/// Son dos tablas y un solo formulario, así que guardarlas es una operación
/// atómica. La dirección referencia a la empresa, de modo que al dar de alta hay
/// que insertar primero la empresa para tener su id: si esa segunda inserción
/// falla fuera de una transacción, queda una empresa sin dirección y el ticket
/// se imprime incompleto.
///
/// La contraseña de la cuenta de correo es la excepción: no vive en la base
/// sino en [SecretosCorreo], cifrada. Para la pantalla da igual, porque aquí se
/// junta con lo demás al leer y se separa al guardar.
class EmpresaLocalDatasource {
  const EmpresaLocalDatasource(
    this._db,
    this._empresa,
    this._direcciones,
    this._secretos,
  );

  final AppDatabase _db;
  final ConfiguracionEmpresaDao _empresa;
  final DireccionDao _direcciones;
  final SecretosCorreo _secretos;

  /// La aplicación maneja una sola empresa, la del registro más bajo.
  static const _empresaId = 1;

  /// La empresa con su dirección, o `null` si todavía no se ha capturado.
  ///
  /// Son dos tablas y un solo modelo: la pantalla no tiene por qué pedirlas
  /// por separado ni saber cómo se juntan. La dirección puede faltar —una
  /// empresa guardada a medias, que la transacción de [guardar] ya evita— y
  /// entonces llega vacía, lista para capturarse.
  Future<EmpresaData?> empresa() async {
    final configuracion = await _empresa.getById(_empresaId);

    if (configuracion == null) return null;

    final empresa = configuracion.toData(
      await _direcciones.getByEmpresaId(_empresaId),
    );

    return empresa.copyWith(
      correoEnvio: empresa.correoEnvio.copyWith(
        password: await _secretos.password(),
      ),
    );
  }

  /// Guarda la empresa y su dirección, dando de alta lo que todavía no exista.
  ///
  /// Sirve para el alta y para la edición: decide por lo que hay en la base en
  /// vez de pedirle a la pantalla que lo sepa, porque la pantalla de
  /// configuración es la misma la primera vez y todas las siguientes.
  ///
  /// La contraseña del correo se guarda al final, cuando la base ya aceptó lo
  /// demás: si la transacción falla, no queda una contraseña nueva junto a
  /// una cuenta vieja.
  Future<void> guardar(EmpresaData empresa) async {
    await _db.transaction(() async {
      final fila = empresa.toCompanion();
      final actual = await _empresa.getById(_empresaId);

      final empresaId = actual == null
          ? await _empresa.insertConfig(fila)
          : actual.id;

      if (actual != null) {
        await _empresa.updateConfig(id: empresaId, row: fila);
      }

      // La dirección siempre cuelga de la empresa que se acaba de escribir, sin
      // importar lo que la pantalla haya puesto en `empresaId`.
      final row = empresa.toDireccionCompanion().copyWith(
        empresaId: Value(empresaId),
      );
      final actualDireccion = await _direcciones.getByEmpresaId(empresaId);

      if (actualDireccion == null) {
        await _direcciones.insertDireccion(row);
        return;
      }

      await _direcciones.updateDireccion(id: actualDireccion.id, row: row);
    });

    await _secretos.guardarPassword(empresa.correoEnvio.password);
  }
}
