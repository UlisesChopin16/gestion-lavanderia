import 'package:flutter/material.dart';

/// El texto que una columna muestra para una fila.
typedef CellValue<T> = String Function(T row);

/// El contenido de una celda cuando no es texto plano.
typedef CellContent<T> = Widget Function(BuildContext context, T row);

/// Cuánto sitio pide una columna.
///
/// La talla dice dos cosas: lo que la columna **no baja** y cuánto se lleva
/// del ancho que sobre. Con ellas la tabla se reparte el ancho que tiene en
/// lugar de medir su contenido y desbordarse: una columna de números no
/// necesita lo mismo que un nombre, y antes todas pedían lo que midiera su
/// texto más largo.
///
/// El mínimo incluye el aire de la celda —la tabla lo mete dentro de la
/// columna—, así que son unos 16 píxeles menos de texto.
@immutable
class TableColumnSize {
  const TableColumnSize._({required this.minimo, required this.peso});

  /// Una columna que no crece: mide [ancho] sobre y falte espacio.
  ///
  /// Para lo que no cambia de tamaño con los datos —los botones de acciones,
  /// una marca—, que no tiene por qué competir por el ancho con las columnas
  /// que sí.
  const TableColumnSize.fija(double ancho) : minimo = ancho, peso = null;

  /// Un número, un chip, una palabra: lo justo para leerlo.
  static const compacta = TableColumnSize._(minimo: 100, peso: 0.6);

  /// Lo de omisión: un dato de una o dos palabras, o una fecha con hora.
  static const normal = TableColumnSize._(minimo: 150, peso: 1);

  /// Un nombre o una descripción: la que se queda con lo que sobre.
  static const amplia = TableColumnSize._(minimo: 190, peso: 1.6);

  /// Lo que la columna no baja. Por debajo de la suma de los mínimos de todas,
  /// la tabla se desplaza en lugar de seguir apretando.
  final double minimo;

  /// Cuánto se lleva del ancho sobrante, frente a las demás columnas. En
  /// `null` la columna no crece.
  final double? peso;

  /// Cómo se lo dice a la tabla.
  ///
  /// `MaxColumnWidth` se queda con el mayor de los dos: el mínimo manda
  /// mientras no haya espacio de sobra, y en cuanto lo hay la columna crece
  /// con su peso.
  TableColumnWidth get width {
    final peso = this.peso;
    if (peso == null) return FixedColumnWidth(minimo);

    return MaxColumnWidth(FlexColumnWidth(peso), FixedColumnWidth(minimo));
  }

  @override
  bool operator ==(Object other) =>
      other is TableColumnSize && other.minimo == minimo && other.peso == peso;

  @override
  int get hashCode => Object.hash(minimo, peso);
}

/// Una columna de `DataTableCard`: el encabezado y cómo sacar de una fila lo
/// que esa columna muestra.
///
/// La columna describe el dato, no construye el widget de la tabla, y el
/// compilador comprueba que la columna y la fila hablan del mismo tipo [T]:
/// pasar un campo que no existe en la fila ya no es un error en tiempo de
/// ejecución.
///
/// [C] es el enum por el que la lista se ordena (`ColumnPreciosName`, por
/// ejemplo). Una columna con [sortBy] es ordenable; sin él, el encabezado no
/// responde al toque.
@immutable
class TableColumnDef<T, C> {
  /// Columna de texto, que es el caso común.
  const TableColumnDef.text({
    required this.title,
    required this.value,
    this.sortBy,
    this.numeric = false,
    this.tooltip,
    this.size = TableColumnSize.normal,
  }) : content = null;

  /// Columna con contenido propio: un chip de estatus, un icono, una barra.
  const TableColumnDef.widget({
    required this.title,
    required this.content,
    this.sortBy,
    this.tooltip,
    this.size = TableColumnSize.normal,
  }) : value = null,
       numeric = false;

  /// Encabezado de la columna.
  final String title;

  /// El texto de la celda, cuando la columna es de texto.
  final CellValue<T>? value;

  /// El widget de la celda, cuando la columna no es de texto.
  final CellContent<T>? content;

  /// Valor del enum de ordenamiento que corresponde a esta columna. En `null`
  /// la columna no se puede ordenar.
  final C? sortBy;

  /// Si la columna contiene números. Se alinean a la derecha para que las
  /// unidades, decenas y centenas queden una debajo de otra y se puedan
  /// comparar de un vistazo.
  final bool numeric;

  final String? tooltip;

  /// Cuánto sitio pide la columna frente a las demás.
  final TableColumnSize size;

  /// El ancho tal como lo entiende `Table`.
  TableColumnWidth get columnWidth => size.width;

  /// Lo que esta columna aporta al ancho mínimo de la tabla.
  double get anchoMinimo => size.minimo;

  bool get isSortable => sortBy != null;

  /// El contenido de la celda para [row].
  Widget buildCell(BuildContext context, T row) {
    final content = this.content;
    if (content != null) return content(context, row);

    final value = this.value;
    if (value == null) return const SizedBox.shrink();

    // Lo que no cabe a lo ancho baja de línea, no se corta: un correo o un
    // nombre largo con puntos suspensivos obliga a abrir el registro para
    // leerlo entero. La fila crece con él —la tabla no le pone tope de alto—,
    // así que lo que se paga es alto, que es lo que sobra, y no el dato.
    return Text(
      value(row),
      textAlign: numeric ? TextAlign.end : TextAlign.center,
    );
  }
}
