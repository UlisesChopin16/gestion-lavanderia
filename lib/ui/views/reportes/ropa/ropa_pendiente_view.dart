import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/ropa_pendiente_view_model.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/barras_horizontales.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/filtro_etiquetas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/grafica_columnas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/indicador_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/pantalla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tabla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tarjeta_estadistica.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';
import 'package:intl/intl.dart';

/// La ropa que falta por entregar: lo atrasado —lo que no se terminó a
/// tiempo—, lo de hoy, lo que viene en la semana y lo que ya está listo y
/// nadie ha venido a recoger, con el teléfono para avisarle al cliente.
///
/// [onVolver] regresa a las tarjetas de la sección de reportes.
class RopaPendienteView extends ConsumerWidget {
  const RopaPendienteView({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ropaPendienteViewModelProvider);
    final notifier = ref.read(ropaPendienteViewModelProvider.notifier);
    final ropa = estado.ropa;

    return PantallaEstadistica(
      titulo: 'Ropa pendiente',
      onVolver: onVolver,
      onRecargar: notifier.recargar,
      cargando: estado.cargando,
      mensajeError: estado.mensajeError,
      contenido: ropa == null
          ? null
          : _Contenido(
              ropa: ropa,
              filtro: estado.filtro,
              onFiltrar: notifier.filtrar,
            ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.ropa,
    required this.filtro,
    required this.onFiltrar,
  });

  final RopaPendiente ropa;
  final FiltroRopa filtro;
  final ValueChanged<FiltroRopa> onFiltrar;

  /// A partir de este ancho, las gráficas van de dos en dos.
  static const double _corteDosColumnas = 900;

  @override
  Widget build(BuildContext context) {
    final atrasadas = ropa.en(EstadoEntrega.atrasada);

    final porVenir = TarjetaEstadistica(
      titulo: 'Lo que hay que terminar',
      nota:
          'Conceptos sin terminar prometidos para cada uno de los próximos '
          '${RopaPendiente.diasPorVenir} días. Hoy va en color.',
      child: _GraficaPorVenir(ropa: ropa),
    );
    final retraso = TarjetaEstadistica(
      titulo: 'Retraso de lo atrasado',
      nota: 'Cuántas órdenes sin terminar llevan ese tiempo de retraso.',
      child: atrasadas.isEmpty
          ? const SinDatos(texto: 'No hay ropa atrasada.', alto: 220)
          : _BarrasRetraso(ropa: ropa),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _Indicadores(ropa: ropa),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _corteDosColumnas) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [porVenir, retraso],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Expanded(flex: 3, child: porVenir),
                  Expanded(flex: 2, child: retraso),
                ],
              ),
            );
          },
        ),
        TarjetaEstadistica(
          titulo: 'Órdenes con ropa pendiente',
          nota:
              'Por folio. "Prometida" es la fecha más próxima de lo que '
              'falta terminar.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              FiltroEtiquetas<FiltroRopa>(
                elegida: filtro,
                onElegir: onFiltrar,
                opciones: [
                  for (final opcion in FiltroRopa.values)
                    (
                      valor: opcion,
                      titulo: opcion.titulo,
                      cuantos: opcion.de(ropa).length,
                    ),
                ],
              ),
              _TablaOrdenes(ordenes: filtro.de(ropa), hoy: ropa.hoy),
            ],
          ),
        ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.ropa});

  final RopaPendiente ropa;

  @override
  Widget build(BuildContext context) {
    final conAlgoListo = ropa.conAlgoListo;
    final pagadas = conAlgoListo.where((orden) => orden.pagada).length;

    return FilaIndicadores(
      indicadores: [
        _IndicadorEstado(
          ropa: ropa,
          estado: EstadoEntrega.atrasada,
          icono: Icons.running_with_errors_rounded,
          titulo: 'Ropa atrasada',
          principal: true,
        ),
        _IndicadorEstado(
          ropa: ropa,
          estado: EstadoEntrega.hoy,
          icono: Icons.today_rounded,
          titulo: EstadoEntrega.hoy.titulo,
        ),
        _IndicadorEstado(
          ropa: ropa,
          estado: EstadoEntrega.proxima,
          icono: Icons.date_range_rounded,
          titulo: EstadoEntrega.proxima.titulo,
        ),
        IndicadorEstadistica(
          icono: Icons.inventory_2_rounded,
          titulo: 'Lista para recoger',
          valor: _conceptos(ropa.conceptosEn(EstadoEntrega.lista)),
          pie: NotaIndicador(
            conAlgoListo.isEmpty
                ? 'Ninguna orden'
                : 'En ${conAlgoListo.length} '
                      '${_ordenes(conAlgoListo.length)} · $pagadas ya '
                      '${pagadas == 1 ? 'pagada' : 'pagadas'}',
          ),
        ),
      ],
    );
  }
}

/// Cuántos conceptos están en un estado, y en cuántas órdenes.
class _IndicadorEstado extends StatelessWidget {
  const _IndicadorEstado({
    required this.ropa,
    required this.estado,
    required this.icono,
    required this.titulo,
    this.principal = false,
  });

  final RopaPendiente ropa;
  final EstadoEntrega estado;
  final IconData icono;
  final String titulo;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final ordenes = ropa.en(estado).length;

    return IndicadorEstadistica(
      icono: icono,
      titulo: titulo,
      valor: _conceptos(ropa.conceptosEn(estado)),
      principal: principal,
      pie: NotaIndicador(
        ordenes == 0 ? 'Ninguna orden' : 'En $ordenes ${_ordenes(ordenes)}',
      ),
    );
  }
}

/// Cuántos conceptos sin terminar se prometieron para cada uno de los
/// próximos días: la carga de trabajo que viene. Hoy resaltado, los demás en
/// gris.
class _GraficaPorVenir extends StatelessWidget {
  const _GraficaPorVenir({required this.ropa});

  final RopaPendiente ropa;

  static final DateFormat _corto = DateFormat('EEE d', ConstantsManager.locale);

  @override
  Widget build(BuildContext context) {
    return GraficaColumnas(
      soloEnteros: true,
      etiquetaEje: (valor) => '${valor.round()}',
      columnas: [
        for (final (indice, (:dia, :conceptos)) in ropa.porVenir.indexed)
          ColumnaGrafica(
            etiqueta: indice == 0 ? 'Hoy' : _corto.format(dia),
            valor: conceptos.toDouble(),
            titulo: dia.formatLongDate,
            detalle: conceptos == 0 ? 'Nada prometido' : _conceptos(conceptos),
            resaltada: indice == 0,
          ),
      ],
    );
  }
}

/// Cuántas órdenes atrasadas hay en cada grupo de retraso, de lo reciente a
/// lo viejo.
class _BarrasRetraso extends StatelessWidget {
  const _BarrasRetraso({required this.ropa});

  final RopaPendiente ropa;

  @override
  Widget build(BuildContext context) {
    return BarrasHorizontales(
      barras: [
        for (final MapEntry(key: retraso, value: ordenes)
            in ropa.porRetraso.entries)
          DatoBarra(
            etiqueta: retraso.titulo,
            valor: ordenes.toDouble(),
            valorTexto: '$ordenes ${_ordenes(ordenes)}',
          ),
      ],
    );
  }
}

class _TablaOrdenes extends StatelessWidget {
  const _TablaOrdenes({required this.ordenes, required this.hoy});

  final List<OrdenConRopaPendiente> ordenes;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    if (ordenes.isEmpty) {
      return const SinDatos(texto: 'Ninguna orden aquí.', alto: 80);
    }

    return TablaEstadistica(
      columnas: const [
        'Folio',
        'Cliente',
        'Teléfono',
        'Falta entregar',
        'Prometida',
        'Estado',
        'Saldo',
      ],
      alineaciones: const [
        TextAlign.left,
        TextAlign.left,
        TextAlign.left,
        TextAlign.left,
        TextAlign.center,
        TextAlign.right,
        TextAlign.right,
      ],
      anchos: const [1, 1.5, 1.1, 2.4, 1.1, 1.3, 0.9],
      anchoMinimo: 1000,
      filas: [
        for (final orden in ordenes)
          [
            orden.folio,
            orden.cliente,
            orden.telefono,
            orden.conceptos
                .map(
                  (c) =>
                      c.estaLista ? '${c.descripcion} (lista)' : c.descripcion,
                )
                .join(', '),
            orden.prometida?.formatDate ?? '—',
            _estado(orden, hoy),
            orden.pagada ? 'Pagada' : orden.saldo.enPesos,
          ],
      ],
    );
  }

  /// `Atrasada 3 días`, `Para hoy`, `En 2 días`, `Lista hace 2 días`.
  static String _estado(OrdenConRopaPendiente orden, DateTime hoy) {
    if (orden.estadoAl(hoy) == EstadoEntrega.lista) {
      final dias = orden.diasEsperando(hoy);
      return switch (dias) {
        <= 0 => 'Lista hoy',
        1 => 'Lista hace 1 día',
        _ => 'Lista hace $dias días',
      };
    }

    final dias = orden.diasDeRetraso(hoy);
    return switch (dias) {
      0 => 'Para hoy',
      1 => 'Atrasada 1 día',
      > 1 => 'Atrasada $dias días',
      -1 => 'En 1 día',
      _ => 'En ${-dias} días',
    };
  }
}

String _ordenes(int cuantas) => cuantas == 1 ? 'orden' : 'órdenes';

String _conceptos(int cuantos) =>
    cuantos == 1 ? '1 concepto' : '$cuantos conceptos';
