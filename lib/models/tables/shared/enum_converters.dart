import 'package:drift/drift.dart';
import 'package:gestion_lavanderia/types/clothe_size_type.dart';
import 'package:gestion_lavanderia/types/estatus_orden_type.dart';
import 'package:gestion_lavanderia/types/estatus_type.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/types/unit_type.dart';

// Las columnas convertidas salen tipadas en las filas generadas, así que quien
// usa una fila necesita la enumeración: viaja junto con el converter y no hace
// falta importarla aparte.
export 'package:gestion_lavanderia/types/clothe_size_type.dart';
export 'package:gestion_lavanderia/types/estatus_orden_type.dart';
export 'package:gestion_lavanderia/types/estatus_type.dart';
export 'package:gestion_lavanderia/types/metodo_pago_type.dart';
export 'package:gestion_lavanderia/types/unit_type.dart';

/// Converters de las columnas de texto que guardan una enumeración.
///
/// Cada uno lee y escribe exactamente el mismo texto que la columna ya tenía
/// —el `value` o la `description` de la constante—, así que agregarlos no
/// cambia el esquema ni los datos y no hay migración que escribir. Lo que
/// cambia es el tipo con el que la fila sale del generador: `EstatusType` en
/// lugar de `String`.
///
/// Es la razón por la que las filas generadas se pueden entregar tal cual a la
/// interfaz: nadie vuelve a llamar a `fromString` fuera de este archivo, y una
/// columna mal comparada deja de compilar en vez de devolver una lista vacía.
///
/// En las consultas, una columna con converter se compara con `equalsValue` en
/// lugar de `equals`, y sigue sirviendo para `like` y para ordenar porque en
/// SQL continúa siendo texto.

/// La constante `todos` de [EstatusType] sólo existe como opción de filtro.
/// Guardarla dejaría en la columna un texto que ninguna consulta busca, así que
/// [toSql] la rechaza en lugar de escribirla.
class EstatusConverter extends TypeConverter<EstatusType, String> {
  const EstatusConverter();

  @override
  EstatusType fromSql(String fromDb) => EstatusType.fromString(fromDb);

  @override
  String toSql(EstatusType value) {
    if (value == EstatusType.todos) {
      throw ArgumentError.value(
        value,
        'estatus',
        'es una opción de filtro, no un estatus que se pueda guardar',
      );
    }

    return value.value;
  }
}

/// Mismo criterio que [EstatusConverter] con el ciclo de vida de una orden:
/// `todos` es filtro y no se guarda.
class EstatusOrdenConverter extends TypeConverter<EstatusOrdenType, String> {
  const EstatusOrdenConverter();

  @override
  EstatusOrdenType fromSql(String fromDb) =>
      EstatusOrdenType.fromString(fromDb);

  @override
  String toSql(EstatusOrdenType value) {
    if (value == EstatusOrdenType.todos) {
      throw ArgumentError.value(
        value,
        'estatus',
        'es una opción de filtro, no un estatus que se pueda guardar',
      );
    }

    return value.value;
  }
}

class UnitConverter extends TypeConverter<UnitType, String> {
  const UnitConverter();

  @override
  UnitType fromSql(String fromDb) => UnitType.fromString(fromDb);

  @override
  String toSql(UnitType value) => value.value;
}

/// [ClotheSizeType] se guarda por su `description` y no por su `value`, porque
/// es el texto que la columna ya contenía.
class ClotheSizeConverter extends TypeConverter<ClotheSizeType, String> {
  const ClotheSizeConverter();

  @override
  ClotheSizeType fromSql(String fromDb) => ClotheSizeType.fromString(fromDb);

  @override
  String toSql(ClotheSizeType value) => value.description;
}

class MetodoPagoConverter extends TypeConverter<MetodoPagoType, String> {
  const MetodoPagoConverter();

  @override
  MetodoPagoType fromSql(String fromDb) => MetodoPagoType.fromString(fromDb);

  @override
  String toSql(MetodoPagoType value) => value.value;
}
