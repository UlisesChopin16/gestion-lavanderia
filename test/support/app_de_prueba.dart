import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/main.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

/// Arranca la aplicación completa y espera a que termine la lectura inicial.
///
/// Se monta [MyApp] y no el home a secas porque es ahí donde se observa el
/// color de la empresa, y esa observación es la que dispara la lectura de la
/// configuración al abrir.
///
/// La lectura se espera llamando a la misma función que hace la aplicación, en
/// lugar de bombear un rato: cuánto tarda depende de la máquina. Y no se puede
/// usar `pumpAndSettle` antes de eso, porque mientras la configuración se lee
/// hay un indicador de progreso girando y esa espera no terminaría nunca.
Future<void> abrirAplicacion(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: MyApp()));
  await tester.pump();

  final contenedor = ProviderScope.containerOf(
    tester.element(find.byType(MyApp)),
  );

  await contenedor
      .read(configuracionEmpresaViewModelProvider.notifier)
      .cargar();

  await tester.pumpAndSettle();
}
