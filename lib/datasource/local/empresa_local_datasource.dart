import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/configuracion_empresa_dao.dart';
import 'package:gestion_lavanderia/data/local/configuracion_empresa/direccion_dao.dart';

/// Los datos de la lavandería: su configuración y su dirección.
///
/// Son dos tablas y un solo formulario, así que guardarlas es una operación
/// atómica. La dirección referencia a la empresa, de modo que al dar de alta hay
/// que insertar primero la empresa para tener su id: si esa segunda inserción
/// falla fuera de una transacción, queda una empresa sin dirección y el ticket
/// se imprime incompleto.
class EmpresaLocalDatasource {
  const EmpresaLocalDatasource(this._db, this._empresa, this._direcciones);

  final AppDatabase _db;
  final ConfiguracionEmpresaDao _empresa;
  final DireccionDao _direcciones;

  /// La aplicación maneja una sola empresa, la del registro más bajo.
  static const _empresaId = 1;

  Future<ConfiguracionEmpresaEntry?> configuracion() =>
      _empresa.getById(_empresaId);

  Future<DireccionEntry?> direccion() =>
      _direcciones.getByEmpresaId(_empresaId);

  /// Guarda la empresa y su dirección, dando de alta lo que todavía no exista.
  ///
  /// Sirve para el alta y para la edición: decide por lo que hay en la base en
  /// vez de pedirle a la pantalla que lo sepa, porque la pantalla de
  /// configuración es la misma la primera vez y todas las siguientes.
  Future<void> guardar({
    required ConfiguracionEmpresaCompanion empresa,
    required DireccionCompanion direccion,
  }) {
    return _db.transaction(() async {
      final actual = await _empresa.getById(_empresaId);

      final empresaId = actual == null
          ? await _empresa.insertConfig(empresa)
          : actual.id;

      if (actual != null) {
        await _empresa.updateConfig(id: empresaId, row: empresa);
      }

      // La dirección siempre cuelga de la empresa que se acaba de escribir, sin
      // importar lo que la pantalla haya puesto en `empresaId`.
      final row = direccion.copyWith(empresaId: Value(empresaId));
      final actualDireccion = await _direcciones.getByEmpresaId(empresaId);

      if (actualDireccion == null) {
        await _direcciones.insertDireccion(row);
        return;
      }

      await _direcciones.updateDireccion(id: actualDireccion.id, row: row);
    });
  }
}
