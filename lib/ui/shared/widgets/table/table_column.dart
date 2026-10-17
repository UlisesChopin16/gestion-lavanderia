import 'package:flutter/material.dart';

/// El texto que una columna muestra para una fila.
typedef CellValue<T> = String Function(T row);

/// El contenido de una celda cuando no es texto plano.
typedef CellContent<T> = Widget Function(BuildContext context, T row);

/// Una columna de `DataTableCard`: el encabezado y cómo sacar de una fila lo
/// que esa columna muestra.
///
/// La columna describe el dato, no construye el widget de la tabla. Así la
/// tabla puede usar la misma definición para armar la celda de escritorio y el
/// renglón de la vista compacta, y el compilador comprueba que la columna y la
/// fila hablan del mismo tipo [T]: pasar un campo que no existe en la fila ya
/// no es un error en tiempo de ejecución.
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
    this.width,
    this.primary = false,
    this.showOnSmall = true,
  }) : content = null;

  /// Columna con contenido propio: un chip de estatus, un icono, una barra.
  const TableColumnDef.widget({
    required this.title,
    required this.content,
    this.sortBy,
    this.tooltip,
    this.width,
    this.primary = false,
    this.showOnSmall = true,
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

  /// Ancho fijo o proporcional de la columna. En `null` lo decide la tabla a
  /// partir del contenido.
  final TableColumnWidth? width;

  /// Si es el dato que identifica a la fila. La vista compacta lo usa como
  /// título de la tarjeta; el resto de las columnas van en el cuerpo.
  final bool primary;

  /// Si la columna aparece en la vista compacta. Una lista con diez columnas
  /// no cabe en una tarjeta de teléfono, así que las accesorias se marcan en
  /// `false` en lugar de escribir una vista aparte.
  final bool showOnSmall;

  bool get isSortable => sortBy != null;

  /// El contenido de la celda para [row].
  Widget buildCell(BuildContext context, T row) {
    final content = this.content;
    if (content != null) return content(context, row);

    final value = this.value;
    if (value == null) return const SizedBox.shrink();

    return Text(
      value(row),
      textAlign: numeric ? TextAlign.end : TextAlign.center,
    );
  }
}
