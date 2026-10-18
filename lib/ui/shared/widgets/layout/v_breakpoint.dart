/// Los anchos a partir de los que la rejilla cambia de disposición.
///
/// Son los mismos nombres que usa Vuetify, para que `VCol(cols: 12, md: 6)` se
/// lea igual que `<v-col cols="12" md="6">`: lo declarado en un punto de
/// quiebre vale desde ahí hacia arriba, y lo que no se declara se hereda del
/// punto anterior.
///
/// Los anchos son los que documenta Vuetify hoy. En Vuetify 3 eran 600, 960,
/// 1280, 1920 y 2560; si alguna pantalla pide aquellos, se cambian aquí y
/// valen para toda la aplicación.
enum VBreakpoint {
  xs(0),
  sm(600),
  md(840),
  lg(1145),
  xl(1545),
  xxl(2138);

  const VBreakpoint(this.minWidth);

  /// El ancho desde el que empieza este punto de quiebre.
  final double minWidth;

  /// El punto de quiebre al que pertenece [width].
  ///
  /// Un ancho negativo —que no existe, pero que una restricción vacía puede
  /// producir— cae en [xs], que es el que no pide ancho mínimo.
  static VBreakpoint of(double width) {
    var punto = VBreakpoint.xs;

    for (final candidato in values) {
      if (width < candidato.minWidth) break;
      punto = candidato;
    }

    return punto;
  }
}

/// Con qué ancho se elige el punto de quiebre de una fila.
enum VBreakpointSource {
  /// El ancho que la fila recibe de su padre.
  ///
  /// Es lo de omisión porque una fila metida en un panel angosto tiene que
  /// partirse aunque la ventana sea ancha: lo que decide si un filtro cabe es
  /// el hueco que le queda, no el tamaño del monitor.
  container,

  /// El ancho de la ventana, como en la web.
  ///
  /// Sirve cuando varias filas de pantallas distintas tienen que cambiar de
  /// disposición a la vez, aunque cada una viva en un contenedor de otro
  /// tamaño.
  viewport,
}
