import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/cuentas_por_cobrar_view_model.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/barras_horizontales.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/filtro_etiquetas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/indicador_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/pantalla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tabla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tarjeta_estadistica.dart';

/// Las cuentas por cobrar: cuánto se debe, desde cuándo y quién lo debe,
/// con el teléfono para llamarle.
///
/// [onVolver] regresa a las tarjetas de la sección de reportes.
class CuentasPorCobrarView extends ConsumerWidget {
  const CuentasPorCobrarView({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(cuentasPorCobrarViewModelProvider);
    final notifier = ref.read(cuentasPorCobrarViewModelProvider.notifier);
    final cuentas = estado.cuentas;

    return PantallaEstadistica(
      titulo: 'Cuentas por cobrar',
      onVolver: onVolver,
      onRecargar: notifier.recargar,
      cargando: estado.cargando,
      mensajeError: estado.mensajeError,
      contenido: cuentas == null
          ? null
          : _Contenido(
              cuentas: cuentas,
              antiguedad: estado.antiguedad,
              onFiltrar: notifier.filtrar,
            ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.cuentas,
    required this.antiguedad,
    required this.onFiltrar,
  });

  final CuentasPorCobrar cuentas;
  final AntiguedadSaldo? antiguedad;
  final ValueChanged<AntiguedadSaldo?> onFiltrar;

  /// A partir de este ancho, las gráficas van de dos en dos.
  static const double _corteDosColumnas = 900;

  static const _sinSaldos = 'Nadie debe nada. Todas las órdenes están pagadas.';

  @override
  Widget build(BuildContext context) {
    final vacio = cuentas.saldos.isEmpty;

    final porAntiguedad = TarjetaEstadistica(
      titulo: 'Por antigüedad',
      nota: 'Cuánto se debe según cuándo se recibió la orden.',
      child: vacio
          ? const SinDatos(texto: _sinSaldos)
          : _BarrasAntiguedad(cuentas: cuentas),
    );
    final quienesDeben = TarjetaEstadistica(
      titulo: 'Los que más deben',
      nota: 'Pasa el mouse sobre un nombre para ver su teléfono.',
      child: vacio
          ? const SinDatos(texto: _sinSaldos)
          : _BarrasClientes(cuentas: cuentas),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _Indicadores(cuentas: cuentas),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _corteDosColumnas) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [porAntiguedad, quienesDeben],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Expanded(child: porAntiguedad),
                  Expanded(child: quienesDeben),
                ],
              ),
            );
          },
        ),
        TarjetaEstadistica(
          titulo: 'Órdenes con saldo',
          nota: 'Por folio. "Hace" dice cuánto lleva debiendo cada una.',
          child: vacio
              ? const SinDatos(texto: _sinSaldos)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    FiltroEtiquetas<AntiguedadSaldo?>(
                      elegida: antiguedad,
                      onElegir: onFiltrar,
                      opciones: [
                        (
                          valor: null,
                          titulo: 'Todas',
                          cuantos: cuentas.saldos.length,
                        ),
                        for (final MapEntry(
                              key: grupo,
                              value: (:ordenes, saldo: _),
                            )
                            in cuentas.porAntiguedad.entries)
                          (valor: grupo, titulo: grupo.corto, cuantos: ordenes),
                      ],
                    ),
                    _TablaSaldos(
                      saldos: cuentas.de(antiguedad),
                      hoy: cuentas.hoy,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.cuentas});

  final CuentasPorCobrar cuentas;

  @override
  Widget build(BuildContext context) {
    final ordenes = cuentas.saldos.length;
    final clientes = cuentas.clientes;
    final viejas = cuentas.porAntiguedad[AntiguedadSaldo.masDeUnMes]!;
    final masAntigua = cuentas.masAntigua;

    return FilaIndicadores(
      indicadores: [
        IndicadorEstadistica(
          icono: Icons.account_balance_wallet_rounded,
          titulo: 'Por cobrar',
          valor: cuentas.total.enPesos,
          principal: true,
          pie: NotaIndicador('En $ordenes ${_ordenes(ordenes)}'),
        ),
        IndicadorEstadistica(
          icono: Icons.people_alt_rounded,
          titulo: 'Clientes que deben',
          valor: '$clientes',
          pie: NotaIndicador(
            clientes == 0
                ? 'Ninguno'
                : 'En promedio, ${(cuentas.total / clientes).enPesos} cada uno',
          ),
        ),
        IndicadorEstadistica(
          icono: Icons.history_rounded,
          titulo: 'Con más de un mes',
          valor: viejas.saldo.enPesos,
          pie: NotaIndicador(
            viejas.ordenes == 0
                ? 'Ninguna orden'
                : 'En ${viejas.ordenes} ${_ordenes(viejas.ordenes)}',
          ),
        ),
        IndicadorEstadistica(
          icono: Icons.hourglass_bottom_rounded,
          titulo: 'La más antigua',
          valor: masAntigua == null
              ? '—'
              : _dias(masAntigua.diasHasta(cuentas.hoy)),
          pie: NotaIndicador(
            masAntigua == null
                ? 'Ninguna orden'
                : '${masAntigua.folio} · ${masAntigua.cliente}',
          ),
        ),
      ],
    );
  }
}

/// Lo que se debe en cada grupo de antigüedad, en su orden: de lo reciente a
/// lo viejo, que es lo que hay que cobrar primero.
class _BarrasAntiguedad extends StatelessWidget {
  const _BarrasAntiguedad({required this.cuentas});

  final CuentasPorCobrar cuentas;

  @override
  Widget build(BuildContext context) {
    final total = cuentas.total;

    return BarrasHorizontales(
      barras: [
        for (final MapEntry(key: grupo, value: (:saldo, :ordenes))
            in cuentas.porAntiguedad.entries)
          DatoBarra(
            etiqueta: grupo.titulo,
            valor: saldo,
            valorTexto: saldo.enPesos,
            nota: '${total > 0 ? (saldo / total * 100).round() : 0} %',
            detalle: '$ordenes ${_ordenes(ordenes)}',
          ),
      ],
    );
  }
}

/// Los clientes que más deben, del que más al que menos.
class _BarrasClientes extends StatelessWidget {
  const _BarrasClientes({required this.cuentas});

  final CuentasPorCobrar cuentas;

  @override
  Widget build(BuildContext context) {
    return BarrasHorizontales(
      barras: [
        for (final (:cliente, :telefono, :saldo, :ordenes)
            in cuentas.clientesQueMasDeben())
          DatoBarra(
            icono: Icons.person_rounded,
            etiqueta: cliente,
            valor: saldo,
            valorTexto: saldo.enPesos,
            detalle: 'Tel. $telefono · $ordenes ${_ordenes(ordenes)}',
          ),
      ],
    );
  }
}

class _TablaSaldos extends StatelessWidget {
  const _TablaSaldos({required this.saldos, required this.hoy});

  final List<SaldoPendiente> saldos;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    if (saldos.isEmpty) {
      return const SinDatos(texto: 'Ninguna orden en este grupo.', alto: 80);
    }

    return TablaEstadistica(
      columnas: const [
        'Folio',
        'Cliente',
        'Teléfono',
        'Recibida',
        'Hace',
        'Total',
        'Pagado',
        'Saldo',
      ],
      alineaciones: const [
        TextAlign.left,
        TextAlign.left,
        TextAlign.left,
        TextAlign.center,
        TextAlign.right,
        TextAlign.right,
        TextAlign.right,
        TextAlign.right,
      ],
      anchos: const [1, 1.8, 1.2, 1.1, 0.8, 1, 1, 1],
      anchoMinimo: 860,
      filas: [
        for (final saldo in saldos)
          [
            saldo.folio,
            saldo.cliente,
            saldo.telefono,
            saldo.recibida.formatDate,
            _dias(saldo.diasHasta(hoy)),
            saldo.total.enPesos,
            saldo.pagado.enPesos,
            saldo.saldo.enPesos,
          ],
      ],
    );
  }
}

String _ordenes(int cuantas) => cuantas == 1 ? 'orden' : 'órdenes';

/// `Hoy`, `1 día`, `12 días`.
String _dias(int dias) => switch (dias) {
  <= 0 => 'Hoy',
  1 => '1 día',
  _ => '$dias días',
};
