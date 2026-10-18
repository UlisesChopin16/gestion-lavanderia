import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

/// Los campos del formulario de un concepto de precio que se validan.
enum CampoPrecio { nombreConcepto, categoria, diasEntrega, importe }

const int _diasMinimos = 1;

/// Qué le falta al concepto para poder guardarse.
///
/// El tamaño y la unidad no aparecen porque siempre traen un valor: "sin
/// tamaño" y "pieza" son opciones válidas, no campos vacíos. Que el concepto
/// no esté repetido dentro de su categoría lo responde la base al guardar.
Map<CampoPrecio, String> validarPrecio(PrecioData precio) {
  return {
    if (precio.nombreConcepto.normalizeSpaces().isEmpty)
      CampoPrecio.nombreConcepto: 'El nombre del concepto es obligatorio',
    if (precio.categoriaId <= 0)
      CampoPrecio.categoria: 'La categoría es obligatoria',
    if (precio.diasEntrega < _diasMinimos)
      CampoPrecio.diasEntrega: 'Los días de entrega deben ser al menos 1',
    if (precio.importe <= 0)
      CampoPrecio.importe: 'El importe debe ser mayor que cero',
  };
}
