import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/models/data/precios/precio_data.dart';
import 'package:gestion_lavanderia/types/column_precios_name.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

/// Columnas de precios, como las armaría la pantalla.
List<TableColumnDef<PrecioData>> columnas({bool conAcciones = false}) {
  return [
    TableColumnDef.text(
      title: 'Concepto',
      value: (precio) => precio.nombreConcepto,
    ),
    TableColumnDef.text(
      title: 'Categoría',
      value: (precio) => precio.categoria,
    ),
    TableColumnDef.text(
      title: 'Importe',
      value: (precio) => precio.importe.toStringAsFixed(2),
      numeric: true,
    ),
    TableColumnDef.text(
      title: 'Fecha de Creación',
      value: (precio) => precio.fechaCreacion.formatFullDate,
    ),
    if (conAcciones)
      TableColumnDef.widget(
        title: 'Acciones',
        size: const TableColumnSize.fija(TableActionsCell.ancho),
        content: (context, precio) => TableActionsCell(
          actions: [
            TableAction(
              label: 'Editar concepto',
              icon: Icons.edit,
              onPressed: () {},
            ),
          ],
        ),
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

/// [ancho] en `null` deja a la tarjeta todo el de la ventana; con un valor se
/// la acota, que es como se ven las columnas en su ancho mínimo.
Future<void> mostrar(
  WidgetTester tester,
  DataTableCard<PrecioData> card, {
  double? ancho,
}) async {
  Widget contenido = Card(child: card);

  if (ancho != null) {
    // El Align afloja el ancho que el desplazable impone: sin él la tarjeta
    // ocuparía la ventana entera y el SizedBox no serviría de nada.
    contenido = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: ancho, child: contenido),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: contenido)),
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
        DataTableCard<PrecioData>(columns: columnas(), rows: precios),
      );

      expect(find.text('Concepto'), findsOneWidget);
      expect(find.text('Importe'), findsOneWidget);
      expect(find.text('Sábana'), findsOneWidget);
      expect(find.text('Camisa'), findsOneWidget);
      expect(find.text('35.50'), findsOneWidget);
      expect(find.text('01/oct/2026 00:00'), findsOneWidget);
    });

    testWidgets('las acciones son una columna más de la lista', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(conAcciones: true),
          rows: precios,
        ),
      );

      // `DataTable` comprueba con un assert que cada fila tenga tantas celdas
      // como encabezados. Ahora no hay forma de descuadrarlo: la tabla no
      // agrega ninguna columna por su cuenta.
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.columns.length, columnas(conAcciones: true).length);
      expect(find.text('Acciones'), findsOneWidget);
      expect(find.byType(TableActionsCell), findsNWidgets(precios.length));
      for (final row in table.rows) {
        expect(row.cells.length, table.columns.length);
      }
    });

    testWidgets('sin columna de acciones no aparece su encabezado', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(columns: columnas(), rows: precios),
      );

      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.columns.length, columnas().length);
      expect(find.text('Acciones'), findsNothing);
      for (final row in table.rows) {
        expect(row.cells.length, table.columns.length);
      }
    });

    testWidgets('el texto que no cabe baja de línea en vez de cortarse', (
      tester,
    ) async {
      const largo = 'Edredón matrimonial de plumas con funda';

      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(conAcciones: true),
          rows: [
            PrecioData(
              categoriaId: 1,
              categoria: 'Ropa de cama',
              nombreConcepto: largo,
            ),
          ],
        ),
      );

      final celda = tester.widget<Text>(find.text(largo));
      final alto = tester.getSize(find.text(largo)).height;

      // Ni puntos suspensivos ni un solo renglón: el texto se reparte en
      // varios y la fila crece con él.
      expect(celda.overflow, isNot(TextOverflow.ellipsis));
      expect(celda.maxLines, isNull);
      expect(alto, greaterThan(30));
      expect(
        tester.getSize(find.byType(DataTable)).height,
        greaterThan(56 + 52),
      );
    });

    testWidgets('una lista vacía muestra el aviso en lugar de la tabla', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(columns: columnas(), rows: const []),
      );

      expect(find.text('No hay elementos disponibles'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('el nombre de la columna dispone del ancho entero', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: [
            TableColumnDef.text(
              title: 'Fecha de Creación',
              value: (precio) => precio.fechaCreacion.formatFullDate,
            ),
          ],
          rows: precios,
        ),
        ancho: 160,
      );

      // Una sola columna, en su ancho mínimo: lo que mide la tabla menos el
      // aire de las orillas (16 por lado) es del nombre, entero. Cuando el
      // encabezado ordenaba, `DataTable` le quitaba 36 de ahí para reservarle
      // sitio a su flecha, y el nombre se partía en dos renglones teniendo
      // columna de sobra.
      final tabla = tester.getSize(find.byType(DataTable));

      expect(
        tester.getSize(find.text('Fecha de Creación')).width,
        tabla.width - 32,
      );
    });

    testWidgets('el encabezado va del color de la acción principal', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(columns: columnas(), rows: precios),
      );

      // El mismo lleno que el botón de agregar, para que la tabla empiece por
      // una banda que se lee de un golpe.
      final tabla = find.byType(DataTable);
      final scheme = Theme.of(tester.element(tabla)).colorScheme;
      final table = tester.widget<DataTable>(tabla);

      expect(table.headingRowColor?.resolve({}), scheme.primary);
      expect(table.headingTextStyle?.color, scheme.onPrimary);
    });

    testWidgets('la sección de filtros va tal cual, arriba de la lista', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(),
          rows: precios,
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
        DataTableCard<PrecioData>(columns: columnas(), rows: precios),
      );

      expect(find.byKey(DataTableCard.llaveFiltros), findsNothing);
    });

    testWidgets('el encabezado va arriba del todo, cerrado por una línea', (
      tester,
    ) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(),
          rows: precios,
          seccionEncabezado: const Text('Precios de ropa'),
        ),
      );

      final encabezado = tester.getRect(
        find.byKey(DataTableCard.llaveEncabezado),
      );
      final linea = tester.getRect(find.byType(Divider));

      expect(find.text('Precios de ropa'), findsOneWidget);
      expect(linea.top, greaterThan(encabezado.bottom));
      expect(
        linea.bottom,
        lessThan(tester.getRect(find.byType(DataTable)).top),
      );
    });

    testWidgets('sin encabezado no hay línea que cerrar', (tester) async {
      await mostrar(
        tester,
        DataTableCard<PrecioData>(columns: columnas(), rows: precios),
      );

      expect(find.byKey(DataTableCard.llaveEncabezado), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    /// El ancho de la tabla y el del hueco donde vive.
    ///
    /// El marco que la encierra se queda con un píxel por lado, así que la
    /// tabla llena el hueco cuando mide dos menos que él.
    Future<(double tabla, double hueco)> medirTabla(
      WidgetTester tester,
      Size ventana,
    ) async {
      tester.view.physicalSize = ventana;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(conAcciones: true),
          rows: precios,
        ),
      );

      return (
        tester.getSize(find.byType(DataTable)).width,
        tester.getSize(find.byKey(DataTableCard.llaveLista)).width,
      );
    }

    testWidgets('con sitio de sobra la tabla llena el ancho y no se desplaza', (
      tester,
    ) async {
      final (tabla, hueco) = await medirTabla(tester, const Size(1400, 900));

      // Antes cada columna pedía lo que midiera su texto más largo y la tabla
      // nacía desplazable aunque sobrara pantalla.
      expect(tabla, closeTo(hueco - 2, 0.5));
    });

    testWidgets('sin sitio la tabla se queda en su mínimo y se desplaza', (
      tester,
    ) async {
      final (tabla, hueco) = await medirTabla(tester, const Size(620, 900));

      // Por debajo del mínimo deja de apretar: se sale del hueco y lo que
      // sobra se recorre.
      expect(tabla, greaterThan(hueco));
    });

    testWidgets('en una ventana angosta sigue siendo la misma tabla', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Antes, por debajo de cierto ancho, la lista se cambiaba por tarjetas y
      // escondía las columnas marcadas: eran dos listados distintos que había
      // que mantener a la par.
      await mostrar(
        tester,
        DataTableCard<PrecioData>(
          columns: columnas(conAcciones: true),
          rows: precios,
        ),
      );

      expect(find.byType(DataTable), findsOneWidget);
      // Con todas sus columnas, incluidas las que antes se escondían.
      expect(find.text('Sábana'), findsOneWidget);
      expect(find.text('35.50'), findsOneWidget);
      expect(find.text('01/oct/2026 00:00'), findsOneWidget);
    });

    testWidgets('mientras carga no muestra la lista ni el aviso de vacío', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataTableCard<PrecioData>(
              columns: columnas(),
              rows: const [],
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
        DataTableCard<PrecioData>(
          columns: columnas(),
          rows: precios,
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
