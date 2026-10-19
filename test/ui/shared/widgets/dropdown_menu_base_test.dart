import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/dropdown_menu_base.dart';

/// Comprueba lo que el desplegable agrega a `DropdownMenu`: cómo se ve la
/// opción elegida, que el texto siga a la selección venga de donde venga, y
/// que sus opciones no se rehagan en cada reconstrucción del padre.
void main() {
  const opciones = [
    DropdownMenuEntry<String>(
      value: 'efectivo',
      label: 'Efectivo',
      leadingIcon: Icon(Icons.local_atm_rounded),
    ),
    DropdownMenuEntry<String>(
      value: 'tarjeta',
      label: 'Tarjeta',
      leadingIcon: Icon(Icons.credit_card),
    ),
  ];

  /// Monta el desplegable dentro de algo que se puede volver a dibujar con
  /// otro valor, que es como lo usa una pantalla.
  Future<StateSetter> mostrar(
    WidgetTester tester, {
    String? value,
    ValueChanged<String?>? onChanged,
  }) async {
    late StateSetter redibujar;
    var elegido = value;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              redibujar = (cambio) => setState(cambio);

              return DropdownMenuBase<String>(
                label: 'Método de pago',
                width: 300,
                value: elegido,
                items: opciones,
                onChanged: (valor) {
                  setState(() => elegido = valor);
                  onChanged?.call(valor);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return redibujar;
  }

  DropdownMenu<String> desplegable(WidgetTester tester) =>
      tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));

  DropdownMenuEntry<String> opcion(WidgetTester tester, String value) {
    return desplegable(tester).dropdownMenuEntries
        .firstWhere((entry) => entry.value == value);
  }

  testWidgets('la opción elegida se resalta y lleva su palomita', (
    tester,
  ) async {
    await mostrar(tester, value: 'tarjeta');

    final elegida = opcion(tester, 'tarjeta');
    final otra = opcion(tester, 'efectivo');

    expect(elegida.trailingIcon, isA<Icon>());
    expect(elegida.style, isNotNull);
    expect(
      otra.style,
      isNull,
      reason: 'la que no está elegida se pasa tal cual',
    );
  });

  testWidgets('el icono de la elegida toma el color de encima del fondo', (
    tester,
  ) async {
    await mostrar(tester, value: 'tarjeta');

    final scheme = Theme.of(tester.element(find.byType(DropdownMenu<String>)))
        .colorScheme;
    final estilo = opcion(tester, 'tarjeta').style!;

    // El color del icono va aparte del de primer plano: `MenuItemButton` trae
    // el suyo —`onSurfaceVariant`— y sin pisarlo el icono se quedaba gris
    // sobre el fondo primario.
    expect(estilo.backgroundColor?.resolve({}), scheme.primary);
    expect(estilo.foregroundColor?.resolve({}), scheme.onPrimary);
    expect(estilo.iconColor?.resolve({}), scheme.onPrimary);
  });

  testWidgets('las opciones no se rehacen al redibujar el padre', (
    tester,
  ) async {
    final redibujar = await mostrar(tester, value: 'tarjeta');

    final antes = desplegable(tester).dropdownMenuEntries;

    redibujar(() {});
    await tester.pumpAndSettle();

    // La misma lista y no una igual: `DropdownMenu` la compara por identidad,
    // y con una nueva rehace una `GlobalKey` por opción y pierde el resaltado
    // del teclado.
    expect(identical(desplegable(tester).dropdownMenuEntries, antes), isTrue);
  });

  testWidgets('cambiar la selección rehace las opciones y el texto', (
    tester,
  ) async {
    final redibujar = await mostrar(tester, value: 'tarjeta');

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Tarjeta',
    );

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Efectivo').last);
    await tester.pumpAndSettle();

    expect(opcion(tester, 'efectivo').style, isNotNull);
    expect(opcion(tester, 'tarjeta').style, isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Efectivo',
    );

    redibujar(() {});
    await tester.pumpAndSettle();
  });

  testWidgets('quitar la selección desde fuera vacía el campo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: _Anfitrion(opciones: opciones)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Tarjeta',
    );

    // `DropdownMenu` repone su texto cuando cambia la selección, pero sólo si
    // la opción existe: al quitarla se quedaba con el nombre de la anterior.
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });
}

/// Una pantalla que puede dejar la selección en `null`, como hace el botón de
/// limpiar de los filtros.
class _Anfitrion extends StatefulWidget {
  const _Anfitrion({required this.opciones});

  final List<DropdownMenuEntry<String>> opciones;

  @override
  State<_Anfitrion> createState() => _AnfitrionState();
}

class _AnfitrionState extends State<_Anfitrion> {
  String? _elegido = 'tarjeta';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownMenuBase<String>(
          width: 300,
          value: _elegido,
          items: widget.opciones,
          onChanged: (valor) => setState(() => _elegido = valor),
        ),
        TextButton(
          onPressed: () => setState(() => _elegido = null),
          child: const Text('Quitar'),
        ),
      ],
    );
  }
}
