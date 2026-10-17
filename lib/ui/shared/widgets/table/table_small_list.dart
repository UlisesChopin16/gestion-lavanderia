import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_action.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/table/table_column.dart';

/// Las acciones disponibles para una fila.
typedef RowActions<T> = List<TableAction> Function(T row);

/// La tarjeta completa de una fila en la vista compacta.
typedef SmallItemBuilder<T> = Widget Function(
  BuildContext context,
  T row,
  int index,
);

/// Un widget al inicio de la tarjeta: el icono o avatar de la fila.
typedef RowLeadingBuilder<T> = Widget Function(BuildContext context, T row);

/// La misma lista en forma de tarjetas, para ventanas angostas.
///
/// Se arma con las mismas [TableColumnDef] que la tabla, de modo que agregar
/// una columna la agrega en los dos tamaños. Antes cada módulo escribía su
/// propia `SmallView` con los campos copiados a mano, y cualquier cambio en la
/// tabla había que repetirlo —o se olvidaba— en cuatro archivos.
///
/// Para las listas cuya tarjeta no es un título con sus datos debajo, se pasa
/// [itemBuilder] y esta clase sólo aporta el rayado.
class TableSmallList<T, C> extends StatelessWidget {
  const TableSmallList({
    super.key,
    required this.columns,
    required this.rows,
    this.actionsBuilder,
    this.leadingBuilder,
    this.itemBuilder,
    this.onRowTap,
    this.rowKey,
  });

  final List<TableColumnDef<T, C>> columns;
  final List<T> rows;
  final RowActions<T>? actionsBuilder;
  final RowLeadingBuilder<T>? leadingBuilder;
  final SmallItemBuilder<T>? itemBuilder;
  final ValueChanged<T>? onRowTap;
  final Object Function(T row)? rowKey;

  @override
  Widget build(BuildContext context) {
    final stripes = ColorRowTheme.of(context);
    final itemBuilder = this.itemBuilder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, row) in rows.indexed)
          Card(
            key: rowKey == null ? null : ValueKey(rowKey!(row)),
            color: stripes.colorForRow(index),
            child: itemBuilder != null
                ? itemBuilder(context, row, index)
                : _SmallItem<T, C>(
                    columns: columns,
                    row: row,
                    actionsBuilder: actionsBuilder,
                    leadingBuilder: leadingBuilder,
                    onRowTap: onRowTap,
                  ),
          ),
      ],
    );
  }
}

class _SmallItem<T, C> extends StatelessWidget {
  const _SmallItem({
    required this.columns,
    required this.row,
    this.actionsBuilder,
    this.leadingBuilder,
    this.onRowTap,
  });

  final List<TableColumnDef<T, C>> columns;
  final T row;
  final RowActions<T>? actionsBuilder;
  final RowLeadingBuilder<T>? leadingBuilder;
  final ValueChanged<T>? onRowTap;

  /// La columna que da título a la tarjeta: la marcada como `primary` o, si
  /// ninguna lo está, la primera visible.
  TableColumnDef<T, C>? get _titleColumn {
    for (final column in columns) {
      if (column.primary) return column;
    }
    return columns.isEmpty ? null : columns.first;
  }

  List<TableColumnDef<T, C>> get _bodyColumns => columns
      .where((column) => column.showOnSmall && column != _titleColumn)
      .toList();

  @override
  Widget build(BuildContext context) {
    final actions = actionsBuilder?.call(row) ?? const <TableAction>[];
    final titleColumn = _titleColumn;
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    return ListTile(
      leading: leadingBuilder?.call(context, row),
      onTap: onRowTap == null ? null : () => onRowTap!(row),
      title: titleColumn == null
          ? null
          : DefaultTextStyle.merge(
              style: titleStyle,
              child: titleColumn.buildCell(context, row),
            ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            for (final column in _bodyColumns)
              _Field<T, C>(column: column, row: row),
          ],
        ),
      ),
      trailing: actions.isEmpty
          ? null
          : TableActionsCell(actions: actions, compact: true),
    );
  }
}

/// Un dato de la tarjeta, con el encabezado de su columna como etiqueta.
class _Field<T, C> extends StatelessWidget {
  const _Field({required this.column, required this.row});

  final TableColumnDef<T, C> column;
  final T row;

  @override
  Widget build(BuildContext context) {
    final label = '${column.title}: ';
    final value = column.value;
    final labelStyle = DefaultTextStyle.of(context).style
        .copyWith(fontWeight: FontWeight.bold);

    // Una columna de texto cabe en un solo párrafo; una con widget propio se
    // pone al lado de su etiqueta.
    if (value != null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label, style: labelStyle),
            TextSpan(text: value(row)),
          ],
        ),
      );
    }

    return Row(
      spacing: 4,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        Flexible(child: column.buildCell(context, row)),
      ],
    );
  }
}
