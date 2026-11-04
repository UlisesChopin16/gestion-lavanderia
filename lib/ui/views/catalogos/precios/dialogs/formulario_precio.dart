import 'package:flutter/foundation.dart' show immutable;
import 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
import 'package:gestion_lavanderia/validations/precio_validation.dart';

export 'package:gestion_lavanderia/models/data/categorias/categoria_data.dart';
export 'package:gestion_lavanderia/models/data/precios/precio_data.dart';

/// Lo que se captura del precio de un concepto en una categoría, tal cual se
/// escribió.
///
/// Texto y no números: "", "0" y "0.0" son cosas distintas mientras se
/// teclea, y con el número a secas, borrar el importe repondría un `0` en el
/// campo.
@immutable
class PrecioEnCategoria {
  const PrecioEnCategoria({this.importe = '', this.dias = ''});

  final String importe;
  final String dias;

  PrecioEnCategoria copyWith({String? importe, String? dias}) =>
      PrecioEnCategoria(
        importe: importe ?? this.importe,
        dias: dias ?? this.dias,
      );
}

/// Lo que lleva capturado el formulario de un concepto de ropa.
///
/// En la base, un concepto pertenece a una sola categoría. Darlo de alta en
/// varias es crear uno por categoría: comparten nombre, tamaño y unidad, y
/// cada uno tiene su precio y sus días. Esta clase guarda eso —lo común una
/// vez, lo de cada categoría aparte— y arma los conceptos al final.
///
/// Es inmutable y no sabe de pantallas, para poder probar sus reglas sin
/// abrir el diálogo.
@immutable
class FormularioPrecio {
  const FormularioPrecio._({
    required this.original,
    required this.nombre,
    required this.tamano,
    required this.unidad,
    required this.categorias,
    required this.precios,
  });

  /// Un concepto nuevo, sin nada capturado.
  const FormularioPrecio.alta()
    : original = null,
      nombre = '',
      tamano = ClotheSizeType.emptySize,
      unidad = UnitType.pieza,
      categorias = const [],
      precios = const {};

  /// Un concepto que ya existe, con su categoría y su precio.
  factory FormularioPrecio.edicion(PrecioData precio) {
    final categoria = CategoriaData(
      id: precio.categoriaId,
      nombre: precio.categoria,
      diasEntrega: precio.diasEntrega,
    );

    return FormularioPrecio._(
      original: precio,
      nombre: precio.nombreConcepto,
      tamano: precio.clotheSize,
      unidad: precio.tipoUnidad,
      categorias: [categoria],
      precios: {
        categoria.id: PrecioEnCategoria(
          importe: precio.importe.toStringAsFixed(2),
          dias: '${precio.diasEntrega}',
        ),
      },
    );
  }

  /// El concepto que se edita, o `null` en un alta.
  final PrecioData? original;

  final String nombre;
  final ClotheSizeType tamano;
  final UnitType unidad;

  /// Las categorías elegidas, en el orden en que se eligieron: es el orden de
  /// los renglones de precios.
  final List<CategoriaData> categorias;

  /// Lo capturado para cada categoría, por su id.
  ///
  /// Guarda también las de categorías que se quitaron: si se vuelve a elegir
  /// una, aparece con lo que ya se había escrito.
  final Map<int, PrecioEnCategoria> precios;

  bool get esAlta => original == null;

  /// Si se crea más de un concepto.
  bool get variasCategorias => categorias.length > 1;

  bool estaElegida(CategoriaData categoria) =>
      categorias.any((elegida) => elegida.id == categoria.id);

  PrecioEnCategoria precioDe(CategoriaData categoria) =>
      precios[categoria.id] ?? const PrecioEnCategoria();

  FormularioPrecio conNombre(String nombre) => _copia(nombre: nombre);

  FormularioPrecio conTamano(ClotheSizeType tamano) => _copia(tamano: tamano);

  FormularioPrecio conUnidad(UnitType unidad) => _copia(unidad: unidad);

  /// Elige la categoría, o la quita si ya estaba elegida.
  ///
  /// En un alta se pueden elegir varias, y cada una llega con los días de
  /// entrega que tiene la categoría, que es lo que casi siempre corresponde.
  ///
  /// Al editar hay una sola —el concepto ya existe y es de una categoría—:
  /// elegir otra la cambia, y el precio y los días se quedan como estaban,
  /// porque pudieron haberse puesto a propósito.
  FormularioPrecio alternarCategoria(CategoriaData categoria) {
    if (!esAlta) {
      final actual = categorias.isEmpty
          ? const PrecioEnCategoria()
          : precioDe(categorias.first);

      return _copia(
        categorias: [categoria],
        precios: {...precios, categoria.id: actual},
      );
    }

    if (estaElegida(categoria)) {
      return _copia(
        categorias: [
          for (final elegida in categorias)
            if (elegida.id != categoria.id) elegida,
        ],
      );
    }

    return _copia(
      categorias: [...categorias, categoria],
      precios: {
        ...precios,
        categoria.id:
            precios[categoria.id] ??
            PrecioEnCategoria(dias: '${categoria.diasEntrega}'),
      },
    );
  }

  FormularioPrecio conImporte(CategoriaData categoria, String importe) =>
      _conPrecio(categoria, precioDe(categoria).copyWith(importe: importe));

  /// Copia el importe de [origen] a todas las categorías elegidas. Los días
  /// no: esos dependen de cada categoría.
  FormularioPrecio conImporteEnTodas(CategoriaData origen) {
    final importe = precioDe(origen).importe;

    return _copia(
      precios: {
        ...precios,
        for (final categoria in categorias)
          categoria.id: precioDe(categoria).copyWith(importe: importe),
      },
    );
  }

  FormularioPrecio conDias(CategoriaData categoria, String dias) =>
      _conPrecio(categoria, precioDe(categoria).copyWith(dias: dias));

  /// Los conceptos que se van a guardar: uno por categoría elegida.
  List<PrecioData> get conceptos => [
    for (final categoria in categorias) _conceptoEn(categoria),
  ];

  /// Lo que falta de lo que comparten todos: el nombre y alguna categoría.
  Map<CampoPrecio, String> get erroresComunes => {
    if (nombre.trim().isEmpty)
      CampoPrecio.nombreConcepto: 'El nombre del concepto es obligatorio',
    if (categorias.isEmpty)
      CampoPrecio.categoria: esAlta
          ? 'Elige al menos una categoría'
          : 'La categoría es obligatoria',
  };

  /// Lo que falta del precio en [categoria]: el importe y los días.
  Map<CampoPrecio, String> erroresDe(CategoriaData categoria) {
    final errores = validarPrecio(_conceptoEn(categoria));

    return {
      CampoPrecio.importe: ?errores[CampoPrecio.importe],
      CampoPrecio.diasEntrega: ?errores[CampoPrecio.diasEntrega],
    };
  }

  /// La primera categoría a la que le falta algo, o `null` si todas están
  /// completas.
  CategoriaData? get primeraIncompleta {
    for (final categoria in categorias) {
      if (erroresDe(categoria).isNotEmpty) return categoria;
    }

    return null;
  }

  bool get completo => erroresComunes.isEmpty && primeraIncompleta == null;

  PrecioData _conceptoEn(CategoriaData categoria) {
    final precio = precioDe(categoria);
    final base =
        original ??
        const PrecioData(categoriaId: 0, categoria: '', nombreConcepto: '');

    return base.copyWith(
      categoriaId: categoria.id,
      categoria: categoria.nombre,
      nombreConcepto: nombre,
      clotheSize: tamano,
      tipoUnidad: unidad,
      importe: double.tryParse(precio.importe) ?? 0,
      diasEntrega: int.tryParse(precio.dias) ?? 0,
    );
  }

  FormularioPrecio _conPrecio(
    CategoriaData categoria,
    PrecioEnCategoria precio,
  ) => _copia(precios: {...precios, categoria.id: precio});

  FormularioPrecio _copia({
    String? nombre,
    ClotheSizeType? tamano,
    UnitType? unidad,
    List<CategoriaData>? categorias,
    Map<int, PrecioEnCategoria>? precios,
  }) {
    return FormularioPrecio._(
      original: original,
      nombre: nombre ?? this.nombre,
      tamano: tamano ?? this.tamano,
      unidad: unidad ?? this.unidad,
      categorias: categorias ?? this.categorias,
      precios: precios ?? this.precios,
    );
  }
}
