import 'package:gestion_lavanderia/extensions/string_ext.dart';

/// Los campos del formulario de una categoría que se validan.
enum CampoCategoria { nombre, diasEntrega }

/// Lo menos que puede tardar una entrega: el mismo día no es una opción
/// porque la fecha de entrega se calcula sumando estos días a la de captura.
const int _diasMinimos = 1;

/// Qué le falta a la categoría capturada para poder guardarse.
///
/// Que el nombre no se repita no se revisa aquí: eso lo sabe la base, que es
/// la única que ve las demás categorías —incluidas las dadas de baja—, y lo
/// responde con un error al guardar.
Map<CampoCategoria, String> validarCategoria({
  required String nombre,
  required int diasEntrega,
}) {
  return {
    if (nombre.normalizeSpaces().isEmpty)
      CampoCategoria.nombre: 'El nombre es obligatorio',
    if (diasEntrega < _diasMinimos)
      CampoCategoria.diasEntrega: 'Los días de entrega deben ser al menos 1',
  };
}
