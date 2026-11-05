import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/extensions/double_ext.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/views/reportes/widgets/barras_horizontales.dart';

/// Lo cobrado por método de pago, de la mayor a la menor, con el importe y
/// su parte del total escritos.
class BarrasMetodo extends StatelessWidget {
  const BarrasMetodo({super.key, required this.porMetodo, required this.total});

  final Map<MetodoPagoType, double> porMetodo;
  final double total;

  @override
  Widget build(BuildContext context) {
    final ordenados = porMetodo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BarrasHorizontales(
      barras: [
        for (final MapEntry(key: metodo, value: importe) in ordenados)
          DatoBarra(
            icono: metodo.icon,
            etiqueta: metodo.value,
            valor: importe,
            valorTexto: importe.enPesos,
            nota: '${_porcentaje(importe, decimales: 0)} %',
            detalle:
                '${metodo.value}: ${importe.enPesos}, '
                '${_porcentaje(importe, decimales: 1)} % de lo cobrado',
          ),
      ],
    );
  }

  String _porcentaje(double importe, {required int decimales}) =>
      (total > 0 ? importe / total * 100 : 0).toStringAsFixed(decimales);
}
