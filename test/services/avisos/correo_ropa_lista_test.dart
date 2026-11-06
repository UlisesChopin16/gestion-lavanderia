import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_lavanderia/models/data/configuracion_empresa/empresa_data.dart';
import 'package:gestion_lavanderia/models/data/ordenes/orden_detalle_data.dart';
import 'package:gestion_lavanderia/services/avisos/aviso_ropa_lista.dart';
import 'package:gestion_lavanderia/services/avisos/correo_ropa_lista.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';

/// El correo de ropa lista: qué ropa anuncia, qué dice del saldo, y cuándo
/// se envía.
void main() {
  final hoy = DateTime(2026, 11, 5);

  ItemOrdenData item(
    String nombre, {
    double cantidad = 1,
    UnitType unidad = UnitType.pieza,
    bool lista = false,
    bool entregada = false,
  }) => ItemOrdenData(
    id: nombre.hashCode,
    precio: PrecioData(
      categoriaId: 1,
      categoria: 'Planchado',
      nombreConcepto: nombre,
      tipoUnidad: unidad,
    ),
    cantidad: cantidad,
    fechaEntrega: hoy,
    fechaLista: lista || entregada ? hoy : null,
    estaEntregado: entregada,
    fechaEntregado: entregada ? hoy : null,
  );

  OrdenDetalleData orden({
    double restante = 0,
    String correo = 'lucia@correo.com',
    List<ItemOrdenData>? items,
  }) => OrdenDetalleData(
    id: 1,
    folio: '2611-0004',
    clienteId: 1,
    cliente: 'Lu<b>cía Pérez',
    clienteCorreo: correo,
    estatus: EstatusOrdenType.enCurso,
    total: 300,
    restante: restante,
    fechaCreacion: hoy,
    items:
        items ??
        [
          item('Camisa', cantidad: 3, lista: true),
          item(
            'Ropa de color',
            cantidad: 2.5,
            unidad: UnitType.kilo,
            lista: true,
          ),
          item('Edredón'),
          item('Pantalón', entregada: true),
        ],
  );

  const empresa = EmpresaData(
    id: 1,
    nombre: 'Lavandería El Sol',
    telefono: '5551234567',
    color: Colors.indigo,
    correoEnvio: CorreoEnvioData(
      servidor: 'smtp.gmail.com',
      puerto: 587,
      usuario: 'sol@gmail.com',
      password: 'clave',
    ),
  );

  test('anuncia sólo lo listo que no se ha llevado', () {
    final html = CorreoRopaLista.html(orden(), empresa);

    expect(CorreoRopaLista.listos(orden()).map((i) => i.concepto), [
      'Camisa',
      'Ropa de color',
    ]);
    expect(html, contains('3 Piezas'));
    expect(html, contains('2.5 Kgs'));
    expect(html, isNot(contains('Pantalón')));
    // El edredón no está listo: no se anuncia, pero se dice que falta.
    expect(html, isNot(contains('Edredón')));
    expect(html, contains('trabajando en 1 concepto más'));
  });

  test('dice si queda saldo o si ya está pagada', () {
    expect(
      CorreoRopaLista.html(orden(restante: 120), empresa),
      contains(r'queda un saldo de <b>$120.00</b>'),
    );
    expect(
      CorreoRopaLista.html(orden(), empresa),
      contains('ya está <b>pagada</b>'),
    );
  });

  test('escapa el nombre del cliente y lleva el folio en el asunto', () {
    expect(
      CorreoRopaLista.html(orden(), empresa),
      contains('Hola Lu&lt;b&gt;cía:'),
    );
    expect(
      CorreoRopaLista.asunto(orden(), empresa),
      'Tu ropa de la orden 2611-0004 está lista · Lavandería El Sol',
    );
  });

  group('el aviso', () {
    const encendido = AvisoRopaLista(EnvioCorreo(), habilitado: true);

    test('apagado no avisa a nadie', () {
      expect(
        const AvisoRopaLista(EnvioCorreo()).avisaA(orden(), empresa),
        isFalse,
      );
    });

    test('encendido avisa sólo con cuenta y con correo del cliente', () {
      expect(encendido.avisaA(orden(), empresa), isTrue);
      expect(encendido.avisaA(orden(correo: '  '), empresa), isFalse);
      expect(
        encendido.avisaA(
          orden(),
          empresa.copyWith(correoEnvio: const CorreoEnvioData()),
        ),
        isFalse,
      );
      expect(encendido.avisaA(orden(), null), isFalse);
    });
  });
}
