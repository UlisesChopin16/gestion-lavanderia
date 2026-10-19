import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/dropdown_menu_base.dart';

export 'package:gestion_lavanderia/types/metodo_pago_type.dart';

/// Acota el listado por cómo se cobró la orden la última vez.
///
/// Es el método del último movimiento, que es el que muestra la columna: una
/// orden abonada en efectivo y liquidada con tarjeta aparece como tarjeta,
/// porque es lo último que pasó con ella.
class FiltroMetodoPago extends StatelessWidget {
  const FiltroMetodoPago({
    super.key,
    required this.metodoPago,
    required this.onChanged,
    this.width,
  });

  /// El método elegido, o `null` cuando se ven todos.
  final MetodoPagoType? metodoPago;

  /// Recibe `null` cuando se quita el filtro.
  final ValueChanged<MetodoPagoType?> onChanged;

  /// El ancho del desplegable. En `null` llena la columna que lo reciba.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<MetodoPagoType>(
      label: 'Método de pago',
      width: width,
      value: metodoPago,
      showDelete: metodoPago != null,
      onDelete: () => onChanged(null),
      leadingIcon: Icon(metodoPago?.icon ?? Icons.payments_outlined),
      items: [
        for (final opcion in MetodoPagoType.values)
          DropdownMenuEntry<MetodoPagoType>(
            value: opcion,
            label: opcion.value,
            leadingIcon: Icon(opcion.icon),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
