import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/logo_storage.dart';
import 'package:gestion_lavanderia/services/secretos_correo.dart';
import 'package:gestion_lavanderia/theme/colores_empresa.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

import '../../../support/inyeccion_de_prueba.dart';

/// Un selector de logo que no abre el diálogo del sistema: devuelve siempre la
/// misma ruta, como si el usuario hubiera elegido una imagen.
class LogoFalso extends LogoStorage {
  const LogoFalso(this.ruta);

  final String? ruta;

  @override
  Future<String?> elegirLogo({String? rutaAnterior}) async {
    rutaPedida = rutaAnterior;
    return ruta;
  }

  static String? rutaPedida;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  /// El formulario con una empresa completa capturada, lista para guardar.
  void capturarEmpresa(ConfiguracionEmpresaViewModel notifier) {
    notifier
      ..cambiarNombre('Lavandería El Sol')
      ..cambiarTelefono('5512345678')
      ..cambiarCorreo('contacto@elsol.com')
      ..cambiarPaginaWeb('www.elsol.com')
      ..cambiarPassword('admin')
      ..cambiarColor(ColoresEmpresa.teal)
      ..cambiarDireccion(
        const DireccionData(
          calle: 'Reforma',
          numeroExterior: '123',
          colonia: 'Centro',
          codigoPostal: 6000,
          ciudad: 'Ciudad de México',
          estado: 'CDMX',
        ),
      );
  }

  ConfiguracionEmpresaViewModel notificador() =>
      container.read(configuracionEmpresaViewModelProvider.notifier);

  ConfiguracionEmpresaState estado() =>
      container.read(configuracionEmpresaViewModelProvider);

  /// Monta la pantalla y espera la lectura inicial.
  ///
  /// Las dependencias se registran aquí y no en `setUp` porque hay casos que
  /// abren la pantalla dos veces —para comprobar qué pasa al volver a entrar—
  /// y cada una puede traer un selector de logo distinto.
  Future<void> abrirPantalla({
    String? logoElegido = '/logos/logo_1.png',
  }) async {
    await registrarDependenciasDePrueba(db: db, logos: LogoFalso(logoElegido));

    container = ProviderContainer();
    addTearDown(container.dispose);

    // `build` arranca la lectura en una microtarea; se espera la misma llamada
    // para no depender de cuántos ciclos tarde.
    await notificador().cargar();
  }

  setUp(() {
    LogoFalso.rutaPedida = null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await limpiarDependenciasDePrueba();
    await db.close();
  });

  group('al abrir la pantalla', () {
    test('sin configuración guardada queda en alta y editable', () async {
      await abrirPantalla();

      expect(estado().cargando, isFalse);
      expect(estado().esAlta, isTrue);
      expect(estado().editable, isTrue);
      expect(estado().empresa, const EmpresaData());
    });

    test('con configuración guardada la lee y la protege', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      await notificador().guardar();

      // Otra pantalla, la misma base: es lo que pasa al volver a entrar.
      await abrirPantalla();

      expect(estado().esAlta, isFalse);
      expect(estado().editable, isFalse);
      expect(estado().empresa.nombre, 'Lavandería El Sol');
      expect(estado().empresa.color, ColoresEmpresa.teal);
      expect(estado().empresa.direccion.ciudad, 'Ciudad de México');
      expect(estado().empresa.direccion.codigoPostal, 6000);
    });
  });

  group('guardar', () {
    test('un alta escribe la empresa y su dirección', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());

      final resultado = await notificador().guardar();

      expect(resultado, ResultadoGuardado.guardado);

      final empresa = await db.configuracionEmpresaDao.getById(1);
      final direccion = await db.direccionDao.getByEmpresaId(1);

      expect(empresa?.nombre, 'Lavandería El Sol');
      expect(empresa?.color, ColoresEmpresa.teal.toARGB32());
      expect(direccion?.calle, 'Reforma');
      expect(direccion?.empresaId, 1);
    });

    test('deja el formulario con el id de la base y protegido', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());

      await notificador().guardar();

      // Sin volver a leer, el formulario seguiría creyéndose nuevo y el
      // siguiente guardado insertaría un segundo registro.
      expect(estado().empresa.id, 1);
      expect(estado().esAlta, isFalse);
      expect(estado().editable, isFalse);
      expect(estado().empresa.fechaCreacion, isNotNull);
    });

    test('el segundo guardado actualiza en lugar de insertar', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      await notificador().guardar();

      notificador()
        ..habilitarEdicion('admin')
        ..cambiarNombre('Lavandería La Luna');
      await notificador().guardar();

      final todas = await db.select(db.configuracionEmpresa).get();
      final direcciones = await db.select(db.direccion).get();

      expect(todas.length, 1);
      expect(todas.single.nombre, 'Lavandería La Luna');
      expect(direcciones.length, 1);
    });

    test('con campos vacíos no escribe nada y los marca', () async {
      await abrirPantalla();

      final resultado = await notificador().guardar();

      expect(resultado, ResultadoGuardado.camposInvalidos);
      expect(estado().errores[CampoEmpresa.nombre], isNotNull);
      expect(estado().errores[CampoEmpresa.calle], isNotNull);
      expect(estado().mensajeError, isNotEmpty);
      expect(await db.configuracionEmpresaDao.getById(1), isNull);
    });
  });

  group('las marcas de error', () {
    test('no aparecen mientras se escribe por primera vez', () async {
      await abrirPantalla();

      notificador().cambiarCorreo('c');

      expect(estado().errores.hay, isFalse);
    });

    test('se quitan en cuanto el campo queda bien', () async {
      await abrirPantalla();
      await notificador().guardar();

      notificador().cambiarNombre('Lavandería El Sol');

      expect(estado().errores[CampoEmpresa.nombre], isNull);
      expect(estado().errores[CampoEmpresa.telefono], isNotNull);
    });

    test('un campo corregido a medias sigue marcado', () async {
      await abrirPantalla();
      await notificador().guardar();

      notificador().cambiarTelefono('55');

      expect(estado().errores[CampoEmpresa.telefono], isNotNull);
    });
  });

  group('el candado', () {
    test('la contraseña correcta habilita la edición', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      await notificador().guardar();

      expect(notificador().habilitarEdicion('otra'), isFalse);
      expect(estado().editable, isFalse);

      expect(notificador().habilitarEdicion('admin'), isTrue);
      expect(estado().editable, isTrue);
    });

    test('en sólo lectura la contraseña no se descubre', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      await notificador().guardar();

      notificador().alternarPasswordVisible();

      expect(estado().passwordVisible, isFalse);

      notificador()
        ..habilitarEdicion('admin')
        ..alternarPasswordVisible();

      expect(estado().passwordVisible, isTrue);
    });

    test('cancelar descarta lo capturado y vuelve a proteger', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      await notificador().guardar();

      notificador()
        ..habilitarEdicion('admin')
        ..cambiarNombre('Nombre a medio escribir');

      await notificador().cancelarEdicion();

      expect(estado().empresa.nombre, 'Lavandería El Sol');
      expect(estado().editable, isFalse);
    });
  });

  group('el logo', () {
    test('la ruta elegida queda en el formulario', () async {
      await abrirPantalla();

      await notificador().cambiarLogo();

      expect(estado().empresa.logo, '/logos/logo_1.png');
    });

    test('se le informa cuál es el logo que reemplaza', () async {
      await abrirPantalla();

      await notificador().cambiarLogo();
      await notificador().cambiarLogo();

      // El servicio borra el anterior sólo si sabe cuál era.
      expect(LogoFalso.rutaPedida, '/logos/logo_1.png');
    });

    test('cerrar el diálogo sin elegir no borra el logo actual', () async {
      await abrirPantalla();
      await notificador().cambiarLogo();

      // Un contenedor nuevo con un selector que no devuelve nada, sobre la
      // misma base: lo que ya estaba capturado se conserva.
      await abrirPantalla(logoElegido: null);
      capturarEmpresa(notificador());
      await notificador().guardar();
      notificador().habilitarEdicion('admin');

      final antes = estado().empresa.logo;
      await notificador().cambiarLogo();

      expect(estado().empresa.logo, antes);
    });
  });

  group('la cuenta de correo', () {
    const cuenta = CorreoEnvioData(
      servidor: 'smtp.gmail.com',
      puerto: 465,
      usuario: 'tickets@gmail.com',
      password: 'abcd efgh ijkl mnop',
    );

    test('se guarda, y la contraseña fuera de la base', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      notificador().cambiarCorreoEnvio(cuenta);

      expect(await notificador().guardar(), ResultadoGuardado.guardado);

      final fila = await db.configuracionEmpresaDao.getById(1);
      expect(fila?.smtpServidor, 'smtp.gmail.com');
      expect(fila?.smtpPuerto, 465);
      expect(fila?.smtpUsuario, 'tickets@gmail.com');

      // Ninguna columna de la base guarda la contraseña del correo...
      final columnas = await db
          .customSelect('PRAGMA table_info(configuracion_empresa)')
          .map((columna) => columna.read<String>('name'))
          .get();
      expect(columnas.where((c) => c.startsWith('smtp')), hasLength(3));

      // ...vive en el almacén cifrado.
      expect(
        await instance<SecretosCorreo>().password(),
        'abcd efgh ijkl mnop',
      );
    });

    test('al volver a entrar se lee completa', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      notificador().cambiarCorreoEnvio(cuenta);
      await notificador().guardar();

      container.dispose();
      container = ProviderContainer();
      addTearDown(container.dispose);
      await notificador().cargar();

      expect(estado().empresa.correoEnvio, cuenta);
    });

    test('a medias no se guarda y marca lo que falta', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      notificador().cambiarCorreoEnvio(
        const CorreoEnvioData(servidor: 'smtp.gmail.com'),
      );

      expect(await notificador().guardar(), ResultadoGuardado.camposInvalidos);
      expect(estado().errorDe(CampoEmpresa.smtpPassword), isNotNull);
      expect(await db.configuracionEmpresaDao.getById(1), isNull);
    });

    test('quitar la cuenta borra su contraseña', () async {
      await abrirPantalla();
      capturarEmpresa(notificador());
      notificador().cambiarCorreoEnvio(cuenta);
      await notificador().guardar();

      notificador()
        ..habilitarEdicion('admin')
        ..cambiarCorreoEnvio(const CorreoEnvioData());
      await notificador().guardar();

      expect(await instance<SecretosCorreo>().password(), isEmpty);
    });
  });
}
