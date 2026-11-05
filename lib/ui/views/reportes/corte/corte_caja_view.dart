import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/ui/views/reportes/corte/widgets/barras_metodo.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/grafica_columnas.dart';
import 'package:gestion_lavanderia/ui/views/reportes/corte/widgets/indicadores_corte.dart';
import 'package:gestion_lavanderia/ui/views/reportes/corte/widgets/tabla_cobros.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/pantalla_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tarjeta_estadistica.dart';
import 'package:gestion_lavanderia/ui/views/reportes/view_model/corte_caja_view_model.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';
import 'package:intl/intl.dart';

/// El corte de caja de un día, en pantalla y con gráficas: arriba las
/// cifras que se cuentan al cerrar, en medio cómo se repartieron los cobros
/// —por hora, por método y contra los días anteriores— y al final cada
/// cobro.
///
/// [onVolver] regresa a las tarjetas de la sección de reportes.
class CorteCajaView extends ConsumerWidget {
  const CorteCajaView({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(corteCajaViewModelProvider);
    final notifier = ref.read(corteCajaViewModelProvider.notifier);
    final estadisticas = estado.estadisticas;

    return PantallaEstadistica(
      titulo: 'Corte de caja',
      onVolver: onVolver,
      onRecargar: notifier.recargar,
      cargando: estado.cargando,
      mensajeError: estado.mensajeError,
      acciones: [
        _SelectorDia(
          dia: estado.dia,
          onMover: notifier.moverDia,
          onElegir: notifier.elegirDia,
        ),
      ],
      contenido: estadisticas == null
          ? null
          : _Contenido(estadisticas: estadisticas),
    );
  }
}

/// Qué día es, con las flechas para ir al anterior o al siguiente: el corte
/// se revisa día por día.
class _SelectorDia extends StatelessWidget {
  const _SelectorDia({
    required this.dia,
    required this.onMover,
    required this.onElegir,
  });

  final DateTime dia;
  final ValueChanged<int> onMover;
  final ValueChanged<DateTime> onElegir;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().soloDia;
    final esHoy = dia == hoy;
    final fecha = dia.formatLongDate;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Día anterior',
          onPressed: () => onMover(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        OutlinedButton.icon(
          onPressed: () => _elegir(context, hoy),
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: Text(esHoy ? 'Hoy, $fecha' : _mayuscula(fecha)),
        ),
        IconButton(
          tooltip: 'Día siguiente',
          // Mañana todavía no se cobra nada.
          onPressed: esHoy ? null : () => onMover(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Future<void> _elegir(BuildContext context, DateTime hoy) async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: dia,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: 'Día del corte',
    );

    if (elegido != null) onElegir(elegido);
  }

  static String _mayuscula(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estadisticas});

  final EstadisticasCorte estadisticas;

  /// A partir de este ancho, las gráficas van de dos en dos.
  static const double _corteDosColumnas = 900;

  @override
  Widget build(BuildContext context) {
    final corte = estadisticas.corte;
    final sinCobros = corte.cobros.isEmpty;

    final porHora = TarjetaEstadistica(
      titulo: 'Cobrado por hora',
      nota: 'Pasa el mouse sobre una columna para ver su detalle.',
      child: sinCobros
          ? const SinDatos(texto: 'No se cobró nada este día.', alto: 220)
          : _GraficaPorHora(corte: corte),
    );
    final porMetodo = TarjetaEstadistica(
      titulo: 'Por método de pago',
      nota: 'Cuánto entró por cada uno y qué parte es del total.',
      child: sinCobros
          ? const SinDatos(texto: 'No se cobró nada este día.', alto: 220)
          : BarrasMetodo(porMetodo: corte.porMetodo, total: corte.total),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        IndicadoresCorte(estadisticas: estadisticas),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _corteDosColumnas) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [porHora, porMetodo],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Expanded(flex: 3, child: porHora),
                  Expanded(flex: 2, child: porMetodo),
                ],
              ),
            );
          },
        ),
        TarjetaEstadistica(
          titulo: 'Los últimos ${EstadisticasCorte.dias} días',
          nota: 'El día del corte va en color; los anteriores, en gris.',
          child: _GraficaSemana(semana: estadisticas.semana),
        ),
        TarjetaEstadistica(
          titulo: 'Detalle de cobros',
          nota: sinCobros
              ? null
              : '${corte.cobros.length} '
                    '${corte.cobros.length == 1 ? 'cobro' : 'cobros'}, '
                    'por folio.',
          child: sinCobros
              ? const SinDatos(texto: 'No se cobró nada este día.')
              : TablaCobros(cobros: corte.cobros),
        ),
      ],
    );
  }
}

/// Una columna por hora, de la primera a la última de un día normal de
/// trabajo —o más, si hubo cobros fuera de él—, para que las horas sin
/// cobros también se vean.
class _GraficaPorHora extends StatelessWidget {
  const _GraficaPorHora({required this.corte});

  final CorteCaja corte;

  /// El día de trabajo que se dibuja siempre, aunque no haya cobros en
  /// todas sus horas.
  static const int _primeraHora = 8;
  static const int _ultimaHora = 20;

  @override
  Widget build(BuildContext context) {
    final porHora = corte.porHora;
    final cuantos = <int, int>{};
    for (final cobro in corte.cobros) {
      cuantos[cobro.fecha.hour] = (cuantos[cobro.fecha.hour] ?? 0) + 1;
    }

    final desde = math.min(_primeraHora, porHora.keys.fold(24, math.min));
    final hasta = math.max(_ultimaHora, porHora.keys.fold(0, math.max));

    return GraficaColumnas(
      columnas: [
        for (var hora = desde; hora <= hasta; hora++)
          ColumnaGrafica(
            etiqueta: '$hora',
            valor: porHora[hora] ?? 0,
            titulo: 'De $hora:00 a $hora:59',
            detalle: switch (cuantos[hora] ?? 0) {
              0 => 'Sin cobros',
              1 => '${(porHora[hora] ?? 0).enPesos} · 1 cobro',
              final n => '${(porHora[hora] ?? 0).enPesos} · $n cobros',
            },
          ),
      ],
    );
  }
}

/// Lo cobrado en cada uno de los últimos días: el del corte resaltado y los
/// anteriores en gris, como contexto.
class _GraficaSemana extends StatelessWidget {
  const _GraficaSemana({required this.semana});

  final List<CobradoDelDia> semana;

  static final DateFormat _corto = DateFormat('EEE d', ConstantsManager.locale);

  @override
  Widget build(BuildContext context) {
    return GraficaColumnas(
      alto: 200,
      columnas: [
        for (final (indice, (:dia, :total)) in semana.indexed)
          ColumnaGrafica(
            etiqueta: _corto.format(dia),
            valor: total,
            titulo: dia.formatLongDate,
            detalle: total > 0 ? total.enPesos : 'Sin cobros',
            resaltada: indice == semana.length - 1,
          ),
      ],
    );
  }
}
