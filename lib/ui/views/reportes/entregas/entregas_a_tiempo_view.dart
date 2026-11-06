import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/entregas_a_tiempo_view_model.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/barras_horizontales.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/filtro_etiquetas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/grafica_columnas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/indicador_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/pantalla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tabla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tarjeta_estadistica.dart';

/// Las entregas a tiempo: de la ropa que se terminó en el periodo, cuánta
/// quedó lista el día prometido o antes, qué categorías se atrasan, qué se
/// terminó tarde y cuánto tardan los clientes en pasar por ella.
///
/// Se mide cuándo quedó lista y no cuándo se la llevó el cliente: si pasa un
/// día después, la lavandería cumplió igual.
///
/// Sirve para ver si los días de entrega del catálogo son realistas: una
/// categoría que casi nunca cumple promete menos días de los que necesita.
///
/// [onVolver] regresa a las tarjetas de la sección de reportes.
class EntregasATiempoView extends ConsumerWidget {
  const EntregasATiempoView({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(entregasATiempoViewModelProvider);
    final notifier = ref.read(entregasATiempoViewModelProvider.notifier);
    final entregas = estado.entregas;

    return PantallaEstadistica(
      titulo: 'Entregas a tiempo',
      onVolver: onVolver,
      onRecargar: notifier.recargar,
      cargando: estado.cargando,
      mensajeError: estado.mensajeError,
      acciones: [
        _Periodos(elegido: estado.periodo, onElegir: notifier.elegirPeriodo),
      ],
      contenido: entregas == null
          ? null
          : _Contenido(
              entregas: entregas,
              categoria: estado.categoria,
              onFiltrar: notifier.filtrar,
            ),
    );
  }
}

/// Los periodos como etiquetas, junto al título: se ven todos y se cambia
/// con un toque.
class _Periodos extends StatelessWidget {
  const _Periodos({required this.elegido, required this.onElegir});

  final PeriodoReporte elegido;
  final ValueChanged<PeriodoReporte> onElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final periodo in EntregasATiempoViewModel.periodos)
          ChoiceChip(
            label: Text(periodo.titulo),
            selected: periodo == elegido,
            onSelected: (_) => onElegir(periodo),
          ),
      ],
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.entregas,
    required this.categoria,
    required this.onFiltrar,
  });

  final EntregasATiempo entregas;
  final String? categoria;
  final ValueChanged<String?> onFiltrar;

  /// A partir de este ancho, las gráficas van de dos en dos.
  static const double _corteDosColumnas = 900;

  @override
  Widget build(BuildContext context) {
    final rango = entregas.rango;
    final periodo =
        'Lo terminado del ${rango.desde.formatDate} '
        'al ${rango.hasta.formatDate}.';

    if (entregas.terminados.isEmpty) {
      return TarjetaEstadistica(
        titulo: 'Sin ropa terminada',
        nota: periodo,
        child: const SinDatos(texto: 'No se terminó ropa en este periodo.'),
      );
    }

    final porCategoria = TarjetaEstadistica(
      titulo: 'A tiempo por categoría',
      nota: 'De la que más se atrasa a la que mejor cumple.',
      child: _BarrasCategoria(entregas: entregas),
    );
    final cuando = TarjetaEstadistica(
      titulo: 'Cuándo quedó lista',
      nota: 'Contra el día prometido. A tiempo en color; tarde, en gris.',
      child: _GraficaMomento(entregas: entregas),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _Indicadores(entregas: entregas),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _corteDosColumnas) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [porCategoria, cuando],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Expanded(flex: 2, child: porCategoria),
                  Expanded(flex: 3, child: cuando),
                ],
              ),
            );
          },
        ),
        TarjetaEstadistica(
          titulo: 'Terminado tarde',
          nota: '$periodo Por folio.',
          child: _Tarde(
            entregas: entregas,
            categoria: categoria,
            onFiltrar: onFiltrar,
          ),
        ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.entregas});

  final EntregasATiempo entregas;

  @override
  Widget build(BuildContext context) {
    final total = entregas.terminados.length;
    final tarde = entregas.tarde.length;
    final promedio = entregas.retrasoPromedio;
    final mayor = entregas.mayorRetraso;
    final recogida = entregas.recogidaPromedio;
    final sinRecoger = entregas.sinRecoger;

    return FilaIndicadores(
      indicadores: [
        IndicadorEstadistica(
          icono: Icons.verified_rounded,
          titulo: 'A tiempo',
          valor: _porcentaje(entregas.fraccionATiempo ?? 0),
          principal: true,
          pie: NotaIndicador(
            '${entregas.aTiempo} de ${_conceptos(total)} terminados',
          ),
        ),
        IndicadorEstadistica(
          icono: Icons.running_with_errors_rounded,
          titulo: 'Terminados tarde',
          valor: _conceptos(tarde),
          pie: NotaIndicador(
            promedio == null
                ? 'Ninguno'
                : '${promedio.toStringAsFixed(1)} días tarde en promedio',
          ),
        ),
        IndicadorEstadistica(
          icono: Icons.hourglass_bottom_rounded,
          titulo: 'Mayor retraso',
          valor: mayor == null ? '—' : _dias(mayor.retraso),
          pie: NotaIndicador(
            mayor == null
                ? 'Todo salió a tiempo'
                : '${mayor.folio} · ${mayor.descripcion}',
          ),
        ),
        IndicadorEstadistica(
          icono: Icons.directions_walk_rounded,
          titulo: 'Tardan en recoger',
          valor: recogida == null ? '—' : '${recogida.toStringAsFixed(1)} días',
          pie: NotaIndicador(
            sinRecoger == 0
                ? 'En promedio, desde que está lista'
                : '$sinRecoger todavía sin recoger',
          ),
        ),
      ],
    );
  }
}

/// Qué parte de lo entregado salió a tiempo en cada categoría, sobre una
/// escala de 0 a 100 %: una categoría al 60 % no se ve llena sólo por ser
/// la mejor.
class _BarrasCategoria extends StatelessWidget {
  const _BarrasCategoria({required this.entregas});

  final EntregasATiempo entregas;

  @override
  Widget build(BuildContext context) {
    return BarrasHorizontales(
      maximo: 1,
      barras: [
        for (final categoria in entregas.porCategoria)
          DatoBarra(
            etiqueta: categoria.categoria,
            valor: categoria.fraccion,
            valorTexto: _porcentaje(categoria.fraccion),
            nota: '${categoria.aTiempo}/${categoria.terminados}',
            detalle:
                '${categoria.aTiempo} de ${_conceptos(categoria.terminados)} '
                'a tiempo · ${categoria.tarde} tarde',
          ),
      ],
    );
  }
}

/// Cuántos conceptos quedaron listos antes, el día prometido y con cuánto
/// retraso.
class _GraficaMomento extends StatelessWidget {
  const _GraficaMomento({required this.entregas});

  final EntregasATiempo entregas;

  @override
  Widget build(BuildContext context) {
    return GraficaColumnas(
      soloEnteros: true,
      etiquetaEje: (valor) => '${valor.round()}',
      columnas: [
        for (final MapEntry(key: momento, value: cuantos)
            in entregas.porMomento.entries)
          ColumnaGrafica(
            etiqueta: momento.corto,
            valor: cuantos.toDouble(),
            titulo: momento.titulo,
            detalle: _conceptos(cuantos),
            resaltada: momento.aTiempo,
          ),
      ],
    );
  }
}

/// Lo terminado tarde, con un filtro por categoría.
class _Tarde extends StatelessWidget {
  const _Tarde({
    required this.entregas,
    required this.categoria,
    required this.onFiltrar,
  });

  final EntregasATiempo entregas;
  final String? categoria;
  final ValueChanged<String?> onFiltrar;

  @override
  Widget build(BuildContext context) {
    final tarde = entregas.tarde;
    if (tarde.isEmpty) {
      return const SinDatos(texto: 'Todo quedó listo a tiempo.', alto: 80);
    }

    final conRetraso = entregas.porCategoria.where((c) => c.tarde > 0);
    // Una categoría elegida que ya no tiene retrasos —se cambió de periodo—
    // deja de filtrar.
    final elegida = conRetraso.any((c) => c.categoria == categoria)
        ? categoria
        : null;
    final visibles = elegida == null
        ? tarde
        : tarde.where((e) => e.categoria == elegida).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FiltroEtiquetas<String?>(
          elegida: elegida,
          onElegir: onFiltrar,
          opciones: [
            (valor: null, titulo: 'Todas', cuantos: tarde.length),
            for (final c in conRetraso)
              (valor: c.categoria, titulo: c.categoria, cuantos: c.tarde),
          ],
        ),
        TablaEstadistica(
          columnas: const [
            'Folio',
            'Cliente',
            'Concepto',
            'Categoría',
            'Prometida',
            'Lista',
            'Retraso',
          ],
          alineaciones: const [
            TextAlign.left,
            TextAlign.left,
            TextAlign.left,
            TextAlign.left,
            TextAlign.center,
            TextAlign.center,
            TextAlign.right,
          ],
          anchos: const [1, 1.6, 1.8, 1.3, 1.1, 1.1, 0.9],
          anchoMinimo: 900,
          filas: [
            for (final entrega in visibles)
              [
                entrega.folio,
                entrega.cliente,
                entrega.descripcion,
                entrega.categoria,
                entrega.prometida.formatDate,
                entrega.lista.formatDate,
                _dias(entrega.retraso),
              ],
          ],
        ),
      ],
    );
  }
}

/// `85 %`.
String _porcentaje(double fraccion) => '${(fraccion * 100).round()} %';

String _conceptos(int cuantos) =>
    cuantos == 1 ? '1 concepto' : '$cuantos conceptos';

String _dias(int dias) => dias == 1 ? '1 día' : '$dias días';
