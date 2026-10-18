import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/configuracion_empresa_view.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

import '../../../support/inyeccion_de_prueba.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ConstantsManager.initFormats);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await registrarDependenciasDePrueba(db: db);
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  /// Deja guardada una configuración, como la de un equipo ya en uso.
  Future<void> guardarConfiguracion() async {
    final id = await db.configuracionEmpresaDao.insertConfig(
      ConfiguracionEmpresaCompanion.insert(
        nombre: 'Lavandería El Sol',
        telefono: '5512345678',
        correo: 'contacto@elsol.com',
        paginaWeb: 'www.elsol.com',
        color: ColoresEmpresa.teal.toARGB32(),
        password: 'admin',
        fechaCreacion: DateTime(2026, 10, 1),
      ),
    );

    await db.direccionDao.insertDireccion(
      DireccionCompanion.insert(
        empresaId: id,
        calle: 'Reforma',
        numeroExterior: '123',
        colonia: 'Centro',
        codigoPostal: 6000,
        ciudad: 'Ciudad de México',
        estado: 'CDMX',
        numeroInterior: const Value('4B'),
        fechaCreacion: DateTime(2026, 10, 1),
      ),
    );
  }

  /// Dibuja la pantalla y espera a que termine la lectura de la base.
  ///
  /// Se espera la misma llamada que hace la pantalla al nacer, en lugar de
  /// bombear un rato: cuánto tarda la lectura depende de la máquina, y la
  /// primera base en memoria del proceso arranca en frío. Y no se puede esperar
  /// con `pumpAndSettle` antes de eso, porque mientras se lee hay un indicador
  /// de progreso girando y esa espera no terminaría nunca.
  Future<void> abrirPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ConfiguracionEmpresaView())),
    );
    await tester.pump();

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(ConfiguracionEmpresaView)),
    );

    await contenedor
        .read(configuracionEmpresaViewModelProvider.notifier)
        .cargar();

    // Ya sin indicador girando, se puede dejar que terminen las animaciones:
    // el botón flotante que se retira sigue en el árbol mientras se desvanece.
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) =>
      find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

  /// Lo que el campo [etiqueta] tiene escrito.
  ///
  /// Se lee del controlador y no con `find.text`: la pista del campo también es
  /// un texto del árbol —aunque esté transparente— y puede coincidir con el
  /// valor.
  String escrito(WidgetTester tester, String etiqueta) =>
      tester.widget<TextField>(campo(etiqueta)).controller?.text ?? '';

  testWidgets('muestra en los campos lo que llegó de la base', (tester) async {
    await guardarConfiguracion();

    // La lectura termina después de la primera construcción: con
    // `initialValue` —como estaba antes— los campos se quedaban vacíos.
    await abrirPantalla(tester);

    expect(escrito(tester, 'Nombre de la empresa'), 'Lavandería El Sol');
    expect(escrito(tester, 'Teléfono'), '5512345678');
    expect(escrito(tester, 'Calle'), 'Reforma');
    expect(escrito(tester, 'Número interior (opcional)'), '4B');
    expect(escrito(tester, 'Código postal'), '6000');
  });

  testWidgets('en una ventana angosta nada se desborda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Con configuración guardada se dibuja también la barra de protegido, que
    // es donde el texto desbordaba el renglón por reclamar su ancho natural.
    await guardarConfiguracion();
    await abrirPantalla(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('los campos quedan centrados en la tarjeta', (tester) async {
    // A este ancho sólo cabe un campo por renglón: es cuando se notaba que la
    // dirección arrancaba pegada a la izquierda.
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await abrirPantalla(tester);

    const centroDeLaPantalla = 250.0;

    expect(tester.getCenter(campo('Calle')).dx, centroDeLaPantalla);
    expect(tester.getCenter(campo('Ciudad')).dx, centroDeLaPantalla);
  });

  testWidgets('la tarjeta no deja huecos a los lados de los campos', (
    tester,
  ) async {
    // Con los campos de ancho fijo, a este ancho ya no cabían dos por renglón
    // y la tarjeta seguía midiendo lo que miden dos: los campos bajaban de uno
    // en uno con el hueco del otro repartido a los lados.
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await abrirPantalla(tester);

    final tarjeta = tester.getRect(find.byType(Card));
    final calle = tester.getRect(campo('Calle'));
    final numeroExterior = tester.getRect(campo('Número exterior'));

    // Los dos primeros campos de la dirección comparten renglón...
    expect(calle.top, numeroExterior.top);

    // ...y entre ellos y el borde de la tarjeta no queda más que el relleno.
    const relleno = 12.0;
    expect(calle.left - tarjeta.left, lessThanOrEqualTo(relleno));
    expect(tarjeta.right - numeroExterior.right, lessThanOrEqualTo(relleno));
  });

  testWidgets('una configuración guardada arranca protegida', (tester) async {
    await guardarConfiguracion();
    await abrirPantalla(tester);

    expect(find.text('Los datos están protegidos.'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    // Sin edición no hay nada que guardar.
    expect(find.text('Guardar datos'), findsNothing);

    final nombre = tester.widget<TextField>(campo('Nombre de la empresa'));
    expect(nombre.enabled, isFalse);
  });

  testWidgets('la contraseña correcta habilita los campos', (tester) async {
    await guardarConfiguracion();
    await abrirPantalla(tester);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'equivocada');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Con la contraseña mal el diálogo sigue abierto y lo dice.
    expect(find.text('La contraseña no coincide'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'admin');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('La contraseña no coincide'), findsNothing);
    expect(find.text('Guardar datos'), findsOneWidget);

    final nombre = tester.widget<TextField>(campo('Nombre de la empresa'));
    expect(nombre.enabled, isTrue);
  });

  testWidgets('un alta nace editable y señala los campos que faltan', (
    tester,
  ) async {
    await abrirPantalla(tester);

    expect(find.text('Los datos están protegidos.'), findsNothing);
    expect(find.text('Guardar datos'), findsOneWidget);

    await tester.tap(find.text('Guardar datos'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa los campos marcados en rojo.'), findsOneWidget);
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La calle es obligatoria'), findsOneWidget);

    // Y la marca se quita al corregir el campo.
    await tester.enterText(campo('Nombre de la empresa'), 'Lavandería El Sol');
    await tester.pumpAndSettle();

    expect(find.text('El nombre es obligatorio'), findsNothing);
    expect(find.text('La calle es obligatoria'), findsOneWidget);
  });
}
