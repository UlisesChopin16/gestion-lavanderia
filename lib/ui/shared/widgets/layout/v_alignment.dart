/// Cómo se alinean las columnas dentro de su renglón, a lo alto.
///
/// Es el `align` de `v-row` —`align-items` en CSS— y también el `align-self`
/// de una columna suelta.
enum VAlign {
  /// Arriba del renglón.
  start,

  /// Centradas en el renglón. Es lo que hace que un botón bajo y un campo de
  /// texto alto se lean como una sola fila de controles.
  center,

  /// Abajo del renglón.
  end,

  /// Por la línea base del texto: los rótulos quedan a la misma altura aunque
  /// los controles midan distinto.
  baseline,

  /// Todas tan altas como la más alta del renglón.
  stretch,
}

/// Cómo se reparte el hueco que sobra a lo ancho de un renglón.
///
/// Es el `justify` de `v-row` (`justify-content`). Sólo se nota cuando sobra
/// espacio, es decir, cuando ninguna columna del renglón crece para llenarlo.
enum VJustify {
  start,
  center,
  end,

  /// El sobrante se reparte entre las columnas, sin aire en los extremos.
  spaceBetween,

  /// Medio hueco en los extremos y uno entero entre columnas.
  spaceAround,

  /// El mismo hueco en los extremos que entre columnas.
  spaceEvenly,
}

/// Cómo se reparten los renglones cuando a la fila le sobra alto.
///
/// Es el `align-content` de `v-row`. Con el alto de omisión —el de su
/// contenido— no hay nada que repartir y no se nota; cuenta cuando la fila
/// recibe un alto mayor del que necesita.
enum VAlignContent {
  start,
  center,
  end,

  /// Los renglones crecen en partes iguales hasta llenar el alto.
  stretch,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// Cuánto aire deja la fila entre sus columnas.
///
/// Son los mismos tres pasos que la densidad de Vuetify, que los calcula sobre
/// un canalón de 24: `comfortable` quita 8 y `compact` —el viejo `dense`—
/// quita 16.
enum VDensity {
  standard(24),
  comfortable(16),
  compact(8);

  const VDensity(this.gutter);

  /// El aire, en píxeles, entre dos columnas y entre dos renglones.
  final double gutter;
}
