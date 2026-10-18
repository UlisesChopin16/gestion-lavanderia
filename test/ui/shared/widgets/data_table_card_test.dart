import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
import 'package:gestion_lavanderia/types/column_precios_name.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// Columnas de precios, como las armaría la pantalla.
///
/// [conCategoria] en `false` reproduce el caso de la lista abierta desde una
/// categoría, donde esa columna no se muestra.
List<TableColumnDef<PrecioData, ColumnPreciosName>> columnas({
  bool conCategoria = true,
}) {
  return [
    TableColumnDef.text(
      title: 'Concepto',
      value: (precio) => precio.nombreConcepto,
      sortBy: ColumnPreciosName.nombre,
      primary: true,
    ),
    if (conCategoria)
      TableColumnDef.text(
        title: 'Categoría',
        value: (precio) => precio.categoria,
        sortBy: ColumnPreciosName.categoria,
      ),
    TableColumnDef.text(
      title: 'Importe',
      value: (precio) => precio.importe.toStringAsFixed(2),
      sortBy: ColumnPreciosName.importe,
      numeric: true,
    ),
    TableColumnDef.text(
      title: 'Fecha de Creación',
      value: (precio) => precio.fechaCreacion.formatFullDate,
      sortBy: ColumnPreciosName.fechaCreacion,
      showOnSmall: false,
    ),
  ];
}

final precios = [
  PrecioData(
    id: 1,
    categoriaId: 1,
    categoria: 'Ropa de cama',
    nombreConcepto: 'Sábana',
    importe: 35.5,
    fechaCreacion: DateTime(2026, 10, 1),
  ),
  PrecioData(
    id: 2,
    categoriaId: 2,
    categoria: 'Ropa fina',
    nombreConcepto: 'Camisa',
    importe: 20,
    fechaCreacion: DateTime(2026, 10, 2),
  ),
];

Future<void> mostrar(
  WidgetTester tester,
  DataTableCard<PrecioData, ColumnPreciosName> card,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Card(child: card)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(ConstantsManager.initFormats);

  group('DataTableCard', () {
    testWidgets('muestra encabezados y datos de cada fila', (tester) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
        ),
      );

      expect(find.text('Concepto'), findsOneWidget);
      expect(find.text('Importe'), findsOneWidget);
      expect(find.text('Sábana'), findsOneWidget);
      expect(find.text('Camisa'), findsOneWidget);
      expect(find.text('35.50'), findsOneWidget);
      expect(find.text('01/oct/2026 00:00'), findsOneWidget);
    });

    testWidgets(
      'agrega la columna de acciones sin que las celdas se desalineen',
      (tester) async {
        await mostrar(
          tester,
          DataTableCard<PrecioData, ColumnPreciosName>(
            columns: columnas(),
            rows: precios,
            forceSmall: false,
            actionsBuilder: (precio) => [
              TableAction(
                label: 'Editar concepto',
                icon: Icons.edit,
                onPressed: () {},
              ),
            ],
          ),
        );

        // `DataTable` comprueba con un assert que cada fila tenga tantas
        // celdas como encabezados: si la tabla agregara la columna sin agregar
        // la celda, este `pump` fallaría.
        final table = tester.widget<DataTable>(find.byType(DataTable));
        expect(table.columns.length, columnas().length + 1);
        expect(find.text('Acciones'), findsOneWidget);
        for (final row in table.rows) {
          expect(row.cells.length, table.columns.length);
        }
      },
    );

    testWidgets('sin actionsBuilder no hay columna de acciones', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
        ),
      );

      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.columns.length, columnas().length);
      expect(find.text('Acciones'), findsNothing);
      for (final row in table.rows) {
        expect(row.cells.length, table.columns.length);
      }
    });

    testWidgets('una lista vacía muestra el aviso en lugar de la tabla', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: const [],
          forceSmall: false,
        ),
      );

      expect(find.text('No hay elementos disponibles'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('marca el encabezado por el que viene ordenada', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          sortedBy: ColumnPreciosName.importe,
          ascending: false,
          onSort: (_, _) {},
        ),
      );

      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.sortColumnIndex, 2);
      expect(table.sortAscending, isFalse);
    });

    testWidgets('no marca ninguna cuando la columna ordenada no está visible', (
      tester,
    ) async {
      // La lista viene ordenada por categoría y la columna de categoría está
      // escondida. Antes la pantalla calculaba el índice con `indexWhere` y
      // pasaba -1, que `DataTable` rechaza con un assert.
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(conCategoria: false),
          rows: precios,
          forceSmall: false,
          sortedBy: ColumnPreciosName.categoria,
          onSort: (_, _) {},
        ),
      );

      expect(tester.takeException(), isNull);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.sortColumnIndex, isNull);
    });

    testWidgets('al tocar un encabezado avisa con la columna y el sentido', (
      tester,
    ) async {
      final cambios = <(ColumnPreciosName, bool)>[];

      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          sortedBy: ColumnPreciosName.nombre,
          ascending: true,
          onSort: (column, ascending) => cambios.add((column, ascending)),
        ),
      );

      // Otra columna empieza ascendente...
      await tester.tap(find.text('Importe'));
      // ...y la que ya ordena invierte el sentido.
      await tester.tap(find.text('Concepto'));

      expect(cambios, [
        (ColumnPreciosName.importe, true),
        (ColumnPreciosName.nombre, false),
      ]);
    });

    testWidgets('la sección de filtros va tal cual, arriba de la lista', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          seccionFiltros: EstatusFilter(
            estatus: EstatusType.activo,
            onChanged: (_) {},
          ),
        ),
      );

      // La tarjeta no la envuelve en nada: el hueco de los filtros es el que
      // ocupa lo que le pasaron.
      final hueco = tester.getRect(find.byKey(DataTableCard.llaveFiltros));
      final filtro = tester.getRect(find.byType(EstatusFilter));

      expect(hueco.top, filtro.top);
      expect(hueco.height, filtro.height);
      expect(hueco.bottom, lessThan(tester.getRect(find.byType(DataTable)).top));
    });

    testWidgets('sin sección de filtros no se dibuja nada', (tester) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
        ),
      );

      expect(find.byKey(DataTableCard.llaveFiltros), findsNothing);
    });

    testWidgets('el botón de agregar necesita texto y callback', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          addLabel: 'Agregar concepto',
        ),
      );

      expect(find.text('Agregar concepto'), findsNothing);

      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          addLabel: 'Agregar concepto',
          onAdd: () {},
        ),
      );

      expect(find.text('Agregar concepto'), findsOneWidget);
    });

    testWidgets('en una ventana angosta muestra tarjetas y no la tabla', (
      tester,
    ) async {
      // El ancho de la superficie de prueba (800) queda por debajo del corte.
      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          actionsBuilder: (precio) => [
            TableAction(
              label: 'Editar concepto',
              icon: Icons.edit,
              onPressed: () {},
            ),
          ],
        ),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(
        find.byType(TableSmallList<PrecioData, ColumnPreciosName>),
        findsOneWidget,
      );
      // El título de la tarjeta es la columna marcada como `primary`...
      expect(find.text('Sábana'), findsOneWidget);
      // ...los demás datos llevan el encabezado de su columna como etiqueta...
      expect(find.textContaining('Importe: 35.50'), findsOneWidget);
      // ...y la columna marcada con `showOnSmall: false` no aparece.
      expect(find.textContaining('01/oct/2026'), findsNothing);
    });

    testWidgets('mientras carga no muestra la lista ni el aviso de vacío', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataTableCard<PrecioData, ColumnPreciosName>(
              columns: columnas(),
              rows: const [],
              forceSmall: false,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No hay elementos disponibles'), findsNothing);
      expect(find.byType(DataTable), findsNothing);
    });
  });

  /// El renglón de filtros, medido dentro de la tarjeta.
  ///
  /// La sección la arma la pantalla, así que aquí se reproduce la que armaría
  /// un catálogo: antes el buscador medía 320 y cada filtro 200 o 220, pasara
  /// lo que pasara, y en una ventana ancha los controles se apelotonaban a la
  /// izquierda dejando el resto del renglón vacío.
  group('DataTableCard · renglón de filtros', () {
    Future<void> mostrarFiltros(WidgetTester tester, Size ventana) async {
      tester.view.physicalSize = ventana;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await mostrar(
        tester,
        DataTableCard<PrecioData, ColumnPreciosName>(
          columns: columnas(),
          rows: precios,
          forceSmall: false,
          seccionFiltros: VRow(
            gutter: 12,
            align: VAlign.center,
            children: [
              VCol(
                cols: 12,
                md: 5,
                lg: 4,
                xl: 3,
                minWidth: SearchFilter.anchoMinimo,
                child: SearchFilter(value: '', onChanged: (_) {}),
              ),
              VCol(
                cols: 12,
                sm: 6,
                md: VCol.grow,
                minWidth: DropdownMenuBase.anchoMinimo,
                maxWidth: DropdownMenuBase.anchoMaximo,
                child: EstatusFilter(
                  estatus: EstatusType.activo,
                  onChanged: (_) {},
                ),
              ),
              VCol(
                cols: 12,
                sm: 6,
                md: VCol.grow,
                minWidth: DropdownMenuBase.anchoMinimo,
                maxWidth: DropdownMenuBase.anchoMaximo,
                child: SortDropdown<ColumnPreciosName>(
                  columns: ColumnPreciosName.values,
                  selected: ColumnPreciosName.nombre,
                  ascending: true,
                  onColumnChanged: (_) {},
                  onAscendingChanged: (_) {},
                ),
              ),
              VCol(
                cols: 12,
                sm: VCol.auto,
                child: ButtonClearFilters(onPressed: () {}),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('en una ventana ancha los controles llenan el renglón', (
      tester,
    ) async {
      await mostrarFiltros(tester, const Size(1400, 900));

      final renglon = tester.getRect(find.byType(VRow));
      final buscador = tester.getRect(find.byType(TextField).first);
      final estatus = tester.getRect(find.byType(EstatusFilter));
      final orden = tester.getRect(
        find.byType(SortDropdown<ColumnPreciosName>),
      );
      final limpiar = tester.getRect(find.byType(ButtonClearFilters));

      // Los cuatro en la misma línea, de un borde al otro del renglón.
      for (final control in [estatus, orden, limpiar]) {
        expect(control.center.dy, closeTo(buscador.center.dy, 1));
      }
      expect(buscador.left, closeTo(renglon.left, 1));
      expect(limpiar.right, closeTo(renglon.right, 1));

      // Y los filtros se quedan con lo que el buscador no usa, en lugar de
      // los 200 de ancho fijo que tenían.
      expect(estatus.width, greaterThan(220));
      expect(estatus.width, closeTo(orden.width, 1));
      expect(buscador.width, greaterThan(estatus.width));
    });

    testWidgets('en una ventana angosta cada control ocupa el renglón', (
      tester,
    ) async {
      await mostrarFiltros(tester, const Size(500, 900));

      final renglon = tester.getRect(find.byType(VRow));
      final buscador = tester.getRect(find.byType(TextField).first);
      final estatus = tester.getRect(find.byType(EstatusFilter));

      expect(buscador.width, closeTo(renglon.width, 1));
      expect(estatus.width, closeTo(renglon.width, 1));
      expect(estatus.top, greaterThan(buscador.bottom));
    });
  });

  group('TableActionsCell', () {
    Future<void> mostrarAcciones(
      WidgetTester tester,
      List<TableAction> actions, {
      bool compact = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableActionsCell(actions: actions, compact: compact),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con pocas acciones las muestra en línea', (tester) async {
      await mostrarAcciones(tester, [
        TableAction(label: 'Editar', icon: Icons.edit, onPressed: () {}),
        TableAction(label: 'Eliminar', icon: Icons.delete, onPressed: () {}),
      ]);

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byType(PopupMenuButton<TableAction>), findsNothing);
    });

    testWidgets('con más de dos las agrupa en un menú', (tester) async {
      var editadas = 0;

      await mostrarAcciones(tester, [
        TableAction(
          label: 'Editar',
          icon: Icons.edit,
          onPressed: () => editadas++,
        ),
        TableAction(label: 'Eliminar', icon: Icons.delete, onPressed: () {}),
        TableAction(label: 'Restaurar', icon: Icons.restore, onPressed: () {}),
      ]);

      expect(find.byType(PopupMenuButton<TableAction>), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<TableAction>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(editadas, 1);
    });

    testWidgets('una acción sin callback se muestra deshabilitada', (
      tester,
    ) async {
      await mostrarAcciones(tester, [
        const TableAction(label: 'Editar', icon: Icons.edit),
      ]);

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('sin acciones no ocupa espacio', (tester) async {
      await mostrarAcciones(tester, const []);

      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(PopupMenuButton<TableAction>), findsNothing);
    });
  });
}
