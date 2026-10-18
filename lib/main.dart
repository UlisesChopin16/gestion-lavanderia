import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/inject/app_module.dart';
import 'package:gestion_lavanderia/theme/theme_app.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';
import 'package:gestion_lavanderia/ui/views/home/home_view.dart';
import 'package:gestion_lavanderia/ui/views/home/view_model/home_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';

Future<void> main() async {
  // Las dependencias y los formatos de fecha se preparan antes de dibujar: la
  // primera pantalla ya resuelve servicios por get_it y muestra fechas.
  WidgetsFlutterBinding.ensureInitialized();
  ConstantsManager.initFormats();
  await const AppModule().injectAll();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El color de la empresa manda el tema de toda la aplicación: al elegirlo
    // en la configuración, el cambio se ve de inmediato en todas las
    // pantallas. Observarlo aquí además hace que la configuración se lea al
    // arrancar, que es cuando hace falta.
    final color = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => estado.empresa.color,
      ),
    );
    final themeMode = ref.watch(
      homeViewModelProvider.select((estado) => estado.themeMode),
    );

    final tema = ThemeApp(seed: color);

    return MaterialApp(
      title: 'Gestión Lavandería',
      debugShowCheckedModeBanner: false,
      theme: tema.light,
      darkTheme: tema.dark,
      themeMode: themeMode,
      // El español no es sólo para los textos propios: los calendarios y los
      // selectores de Material traen los suyos y sin esto saldrían en inglés.
      locale: const Locale('es', 'ES'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'ES')],
      home: const HomeView(),
    );
  }
}
