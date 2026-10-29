import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/validations/empresa_validation.dart';

/// Una empresa completa, a la que cada caso le estropea un campo.
const empresaValida = EmpresaData(
  nombre: 'Lavandería El Sol',
  telefono: '5512345678',
  correo: 'contacto@elsol.com',
  password: 'admin',
  direccion: DireccionData(
    calle: 'Reforma',
    numeroExterior: '123',
    colonia: 'Centro',
    codigoPostal: 6000,
    ciudad: 'Ciudad de México',
    estado: 'CDMX',
  ),
);

void main() {
  group('validarEmpresa', () {
    test('una empresa completa no tiene errores', () {
      expect(validarEmpresa(empresaValida).hay, isFalse);
    });

    test('exige los datos de la empresa y de su dirección', () {
      final errores = validarEmpresa(const EmpresaData());

      expect(errores[CampoEmpresa.nombre], isNotNull);
      expect(errores[CampoEmpresa.telefono], isNotNull);
      expect(errores[CampoEmpresa.password], isNotNull);
      expect(errores[CampoEmpresa.calle], isNotNull);
      expect(errores[CampoEmpresa.numeroExterior], isNotNull);
      expect(errores[CampoEmpresa.colonia], isNotNull);
      expect(errores[CampoEmpresa.codigoPostal], isNotNull);
      expect(errores[CampoEmpresa.ciudad], isNotNull);
      expect(errores[CampoEmpresa.estado], isNotNull);
    });

    test('devuelve todos los errores juntos, no sólo el primero', () {
      expect(validarEmpresa(const EmpresaData()).campos.length, 9);
    });

    test('el correo y la página web son opcionales', () {
      final empresa = empresaValida.copyWith(correo: '', paginaWeb: '');

      expect(validarEmpresa(empresa).hay, isFalse);
    });

    test('pero un correo escrito tiene que ser un correo', () {
      final empresa = empresaValida.copyWith(correo: 'contacto@');

      expect(validarEmpresa(empresa)[CampoEmpresa.correo], isNotNull);
    });

    test('el teléfono necesita sus diez dígitos', () {
      final corto = empresaValida.copyWith(telefono: '55123');

      expect(
        validarEmpresa(corto)[CampoEmpresa.telefono],
        'El teléfono debe tener 10 dígitos',
      );
    });

    test('un espacio en blanco no llena un campo obligatorio', () {
      final empresa = empresaValida.copyWith(nombre: '   ');

      expect(validarEmpresa(empresa)[CampoEmpresa.nombre], isNotNull);
    });

    test('acepta un código postal que empieza con cero', () {
      // 01000 se guarda como 1000 porque la columna es entera: pedir cinco
      // dígitos al número rechazaría los códigos que empiezan con cero.
      final empresa = empresaValida.copyWith(
        direccion: empresaValida.direccion.copyWith(codigoPostal: 1000),
      );

      expect(validarEmpresa(empresa).hay, isFalse);
    });

    test('rechaza un código postal de menos de cuatro dígitos', () {
      final empresa = empresaValida.copyWith(
        direccion: empresaValida.direccion.copyWith(codigoPostal: 100),
      );

      expect(
        validarEmpresa(empresa)[CampoEmpresa.codigoPostal],
        'El código postal debe tener 5 dígitos',
      );
    });
  });

  group('ErroresEmpresa', () {
    test('soloDe conserva nada más los campos pedidos', () {
      final todos = validarEmpresa(const EmpresaData());

      final algunos = todos.soloDe([
        CampoEmpresa.nombre,
        CampoEmpresa.telefono,
      ]);

      expect(algunos.campos, [CampoEmpresa.nombre, CampoEmpresa.telefono]);
      expect(algunos[CampoEmpresa.calle], isNull);
    });

    test('soloDe ignora los campos que ya quedaron bien', () {
      final errores = validarEmpresa(empresaValida.copyWith(nombre: ''));

      final vigentes = errores.soloDe([
        CampoEmpresa.nombre,
        CampoEmpresa.telefono,
      ]);

      expect(vigentes.campos, [CampoEmpresa.nombre]);
    });

    test('dos conjuntos con los mismos motivos son iguales', () {
      // El estado del formulario se compara por valor para decidir si hay que
      // volver a dibujar: sin igualdad profunda, cada tecleo redibujaría todo.
      expect(
        validarEmpresa(const EmpresaData()),
        validarEmpresa(const EmpresaData()),
      );
      expect(
        validarEmpresa(const EmpresaData()).hashCode,
        validarEmpresa(const EmpresaData()).hashCode,
      );
    });
  });

  group('DireccionData', () {
    test('la dirección completa repone el cero del código postal', () {
      const direccion = DireccionData(
        calle: 'Reforma',
        numeroExterior: '123',
        colonia: 'Centro',
        codigoPostal: 1000,
        ciudad: 'Ciudad de México',
        estado: 'CDMX',
      );

      expect(direccion.completa, contains('C.P. 01000'));
      expect(direccion.codigoPostalTexto, '1000');
    });

    test('el número interior sólo aparece cuando lo hay', () {
      const sinInterior = DireccionData(calle: 'Reforma', numeroExterior: '12');

      expect(sinInterior.completa, isNot(contains('Int.')));
      expect(
        sinInterior.copyWith(numeroInterior: '4B').completa,
        contains('Int. 4B,'),
      );
    });
  });

  group('la cuenta de correo', () {
    const completa = CorreoEnvioData(
      servidor: 'smtp.gmail.com',
      puerto: 465,
      usuario: 'tickets@gmail.com',
      password: 'abcd efgh ijkl mnop',
    );

    ErroresEmpresa con(CorreoEnvioData cuenta) =>
        validarEmpresa(empresaValida.copyWith(correoEnvio: cuenta));

    test('vacía no pide nada: es opcional', () {
      expect(con(const CorreoEnvioData()).hay, isFalse);
    });

    test('completa no tiene errores', () {
      expect(con(completa).hay, isFalse);
    });

    test('a medias pide lo que falta', () {
      final errores = con(const CorreoEnvioData(servidor: 'smtp.gmail.com'));

      expect(errores[CampoEmpresa.smtpServidor], isNull);
      expect(errores[CampoEmpresa.smtpPuerto], isNotNull);
      expect(errores[CampoEmpresa.smtpUsuario], isNotNull);
      expect(errores[CampoEmpresa.smtpPassword], isNotNull);
    });

    test('el puerto tiene que existir', () {
      final errores = con(completa.copyWith(puerto: 70000));

      expect(errores[CampoEmpresa.smtpPuerto], isNotNull);
    });

    test('el usuario tiene que ser un correo', () {
      final errores = con(completa.copyWith(usuario: 'tickets'));

      expect(errores[CampoEmpresa.smtpUsuario], isNotNull);
    });
  });
}
