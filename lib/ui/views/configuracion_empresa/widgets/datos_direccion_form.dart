import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/form_text_field.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/widgets/medidas_formulario.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

/// La dirección de la empresa, que es la que sale impresa en el ticket.
class DatosDireccionForm extends ConsumerWidget {
  const DatosDireccionForm({super.key, required this.anchoCampo});

  final double anchoCampo;

  static const _digitosCodigoPostal = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final (direccion, editable, errores) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (estado.empresa.direccion, estado.editable, estado.errores),
      ),
    );

    /// Cada campo manda la dirección completa con lo suyo cambiado: el estado
    /// guarda la dirección como un solo valor.
    void cambiar(DireccionData nueva) => notifier.cambiarDireccion(nueva);

    return Wrap(
      spacing: MedidasFormulario.separacion,
      runSpacing: MedidasFormulario.separacion,
      // Centrado como el encabezado: cuando los campos no caben de dos en dos,
      // el renglón de uno solo se quedaba pegado a la izquierda con todo el
      // hueco a la derecha.
      alignment: WrapAlignment.center,
      children: [
        FormTextField(
          value: direccion.calle,
          onChanged: (calle) => cambiar(direccion.copyWith(calle: calle)),
          enabled: editable,
          width: anchoCampo,
          label: 'Calle',
          icon: Icons.signpost_rounded,
          errorText: errores[CampoEmpresa.calle],
        ),
        FormTextField(
          value: direccion.numeroExterior,
          onChanged: (numero) =>
              cambiar(direccion.copyWith(numeroExterior: numero)),
          enabled: editable,
          width: anchoCampo,
          label: 'Número exterior',
          errorText: errores[CampoEmpresa.numeroExterior],
        ),
        FormTextField(
          value: direccion.numeroInterior ?? '',
          // Un interior vacío se guarda como nulo, que es lo que significa "no
          // tiene" en la columna; una cadena vacía diría que sí tiene y está en
          // blanco.
          onChanged: (numero) => cambiar(
            direccion.copyWith(
              numeroInterior: numero.trim().isEmpty ? null : numero,
            ),
          ),
          enabled: editable,
          width: anchoCampo,
          label: 'Número interior (opcional)',
        ),
        FormTextField(
          value: direccion.colonia,
          onChanged: (colonia) => cambiar(direccion.copyWith(colonia: colonia)),
          enabled: editable,
          width: anchoCampo,
          label: 'Colonia',
          errorText: errores[CampoEmpresa.colonia],
        ),
        FormTextField(
          value: direccion.codigoPostalTexto,
          // Lo que no sea un número se queda en cero, que la validación marca
          // como campo obligatorio.
          onChanged: (codigo) => cambiar(
            direccion.copyWith(codigoPostal: int.tryParse(codigo) ?? 0),
          ),
          enabled: editable,
          width: anchoCampo,
          label: 'Código postal',
          hint: '$_digitosCodigoPostal dígitos',
          errorText: errores[CampoEmpresa.codigoPostal],
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_digitosCodigoPostal),
          ],
        ),
        FormTextField(
          value: direccion.ciudad,
          onChanged: (ciudad) => cambiar(direccion.copyWith(ciudad: ciudad)),
          enabled: editable,
          width: anchoCampo,
          label: 'Ciudad',
          icon: Icons.location_city_rounded,
          errorText: errores[CampoEmpresa.ciudad],
        ),
        FormTextField(
          value: direccion.estado,
          onChanged: (estado) => cambiar(direccion.copyWith(estado: estado)),
          enabled: editable,
          width: anchoCampo,
          label: 'Estado',
          icon: Icons.map_rounded,
          errorText: errores[CampoEmpresa.estado],
        ),
      ],
    );
  }
}
