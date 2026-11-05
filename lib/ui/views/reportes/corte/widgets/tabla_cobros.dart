import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/date_time_ext.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/models/data/reportes/corte_caja.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/tabla_estadistica.dart';

/// Cada cobro del día, por folio: lo que se revisa cuando la caja no cuadra.
/// En efectivo, con cuánto pagó el cliente y su cambio.
class TablaCobros extends StatelessWidget {
  const TablaCobros({super.key, required this.cobros});

  final List<CobroCorte> cobros;

  @override
  Widget build(BuildContext context) {
    return TablaEstadistica(
      columnas: CorteCaja.columnas,
      alineaciones: const [
        TextAlign.left,
        TextAlign.center,
        TextAlign.left,
        TextAlign.left,
        TextAlign.right,
        TextAlign.right,
        TextAlign.right,
      ],
      anchos: const [1.1, 0.7, 2, 1.2, 1.1, 1.1, 1],
      filas: [
        for (final cobro in cobros)
          [
            cobro.folio,
            cobro.fecha.formatTime,
            cobro.cliente,
            cobro.metodo.value,
            cobro.monto.enPesos,
            cobro.entregado?.enPesos ?? '—',
            cobro.cambio?.enPesos ?? '—',
          ],
      ],
    );
  }
}
