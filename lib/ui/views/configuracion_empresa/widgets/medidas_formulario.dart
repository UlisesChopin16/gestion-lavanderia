/// Cómo se reparte el ancho disponible entre los campos de la empresa.
///
/// La tarjeta se mide para las columnas que caben y los formularios acomodan
/// sus campos dentro: los dos tienen que contar igual. Con un ancho de campo
/// fijo no lo hacían, y en una ventana de poco menos de lo que piden dos
/// columnas la tarjeta se quedaba del ancho de las dos mientras los campos ya
/// bajaban de uno en uno: el hueco de la columna que faltaba quedaba repartido
/// a los lados de cada campo.
abstract final class MedidasFormulario {
  /// Lo que separa un campo del siguiente, a lo ancho y a lo alto.
  static const double separacion = 15.0;

  /// Lo más angosto que se deja un campo antes de quitarle una columna.
  static const double anchoMinimo = 320.0;

  /// Lo más ancho que se deja un campo. Más allá el renglón se vuelve incómodo
  /// de leer, así que el sobrante se le quita a la tarjeta en lugar de
  /// repartirlo entre los campos.
  static const double anchoMaximo = 400.0;

  /// Dos columnas como mucho: el encabezado es el logo al lado del formulario
  /// de contacto, y una tercera columna de campos sueltos no tendría con qué
  /// emparejarse.
  static const int _columnasMaximas = 2;

  /// Cuántas columnas de campos caben en [disponible].
  static int columnas(double disponible) {
    // Dentro de algo sin ancho límite no hay nada que repartir; se asume la
    // disposición de ventana amplia.
    if (!disponible.isFinite) return _columnasMaximas;

    final caben = (disponible + separacion) ~/ (anchoMinimo + separacion);

    return caben.clamp(1, _columnasMaximas);
  }

  /// El ancho de cada campo para llenar [disponible] con sus columnas.
  ///
  /// Se redondea hacia abajo para que la suma de las columnas dé exacto: medio
  /// píxel de más y el último campo se va al renglón siguiente, que es
  /// justamente lo que deja la tarjeta con huecos.
  static double anchoCampo(double disponible) {
    final columnas = MedidasFormulario.columnas(disponible);
    final libre = disponible - separacion * (columnas - 1);

    return (libre / columnas).clamp(0.0, anchoMaximo).floorToDouble();
  }

  /// Lo que mide el contenido: las columnas que caben, con su separación.
  static double anchoContenido(double disponible) {
    final columnas = MedidasFormulario.columnas(disponible);

    return anchoCampo(disponible) * columnas + separacion * (columnas - 1);
  }
}
