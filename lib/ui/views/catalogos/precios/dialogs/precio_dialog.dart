import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogs.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';
import 'package:gestion_lavanderia/validations/precio_validation.dart';

/// El formulario de un concepto de ropa, para darlo de alta o editarlo.
///
/// Los campos se acomodan en un `Wrap`: son seis y de ancho fijo, así que en
/// una ventana amplia van de dos en dos y en una angosta se apilan solos.
///
/// Se cierra devolviendo `true` cuando se guardó. Si el concepto ya existe
/// —misma categoría, mismo tamaño, mismo nombre— la base lo rechaza y el
/// diálogo se queda abierto con el motivo a la vista.
class PrecioDialog extends ConsumerStatefulWidget {
  const PrecioDialog({super.key, this.precio});

  /// El concepto que se edita, o `null` para un alta.
  final PrecioData? precio;

  @override
  ConsumerState<PrecioDialog> createState() => _PrecioDialogState();
}

class _PrecioDialogState extends ConsumerState<PrecioDialog> {
  late PrecioData _precio =
      widget.precio ??
      const PrecioData(categoriaId: 0, categoria: '', nombreConcepto: '');

  /// Lo capturado en los dos campos numéricos, tal cual se escribió.
  ///
  /// Se guarda el texto y no sólo el número porque "", "0" y "0.0" son cosas
  /// distintas mientras se teclea: con el número a secas, borrar el importe
  /// repondría un `0` en el campo y habría que borrarlo de nuevo.
  late String _dias = widget.precio == null ? '' : '${widget.precio!.diasEntrega}';
  late String _importe = widget.precio == null
      ? ''
      : widget.precio!.importe.toStringAsFixed(2);

  Map<CampoPrecio, String> _errores = const {};

  static const _anchoCampo = 240.0;
  static const _anchoContenido = 520.0;
  static const _digitosDias = 3;

  bool get _esAlta => widget.precio == null;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(preciosViewModelProvider);

    return Stack(
      children: [
        BaseDialog(
          title: _esAlta ? 'Nuevo concepto de ropa' : 'Editar concepto',
          icon: const Icon(IconsManager.clotheIcon),
          actionText: 'Guardar',
          closeOnAction: false,
          onActionPressed: _guardar,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoContenido),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.center,
                children: [
                  FormTextField(
                    value: _precio.nombreConcepto,
                    onChanged: (valor) => _cambiar(
                      _precio.copyWith(nombreConcepto: valor),
                    ),
                    autofocus: true,
                    width: _anchoCampo,
                    label: 'Nombre del concepto',
                    hint: 'Playera, Pantalón, Sábana',
                    icon: IconsManager.clotheIcon,
                    errorText: _errores[CampoPrecio.nombreConcepto],
                  ),
                  _SelectorCategoria(
                    categorias: estado.categoriasActivas,
                    seleccionada: _precio.categoriaId,
                    error: _errores[CampoPrecio.categoria],
                    onChanged: _elegirCategoria,
                  ),
                  SelectorTamano(
                    tamano: _precio.clotheSize,
                    width: _anchoCampo,
                    onChanged: (tamano) => _cambiar(
                      _precio.copyWith(
                        clotheSize: tamano ?? ClotheSizeType.emptySize,
                      ),
                    ),
                  ),
                  _SelectorUnidad(
                    unidad: _precio.tipoUnidad,
                    onChanged: (unidad) =>
                        _cambiar(_precio.copyWith(tipoUnidad: unidad)),
                  ),
                  FormTextField(
                    value: _dias,
                    onChanged: _cambiarDias,
                    width: _anchoCampo,
                    label: 'Días de entrega',
                    hint: '1, 2, 3...',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_digitosDias),
                    ],
                    errorText: _errores[CampoPrecio.diasEntrega],
                  ),
                  FormTextField(
                    value: _importe,
                    onChanged: _cambiarImporte,
                    width: _anchoCampo,
                    label: 'Importe',
                    hint: '55.50',
                    icon: IconsManager.selectedPreciosIcon,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    errorText: _errores[CampoPrecio.importe],
                    onSubmitted: (_) => _guardar(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (estado.cargando) const AbsorbPointer(child: BlockProgress()),
      ],
    );
  }

  /// Al elegir categoría, un concepto nuevo hereda sus días de entrega, que es
  /// lo que casi siempre corresponde. En una edición no se tocan: el concepto
  /// pudo haberlos cambiado a propósito.
  void _elegirCategoria(CategoriaData categoria) {
    final conCategoria = _precio.copyWith(
      categoriaId: categoria.id,
      categoria: categoria.nombre,
    );

    if (!_esAlta) {
      _cambiar(conCategoria);
      return;
    }

    setState(() => _dias = '${categoria.diasEntrega}');
    _cambiar(conCategoria.copyWith(diasEntrega: categoria.diasEntrega));
  }

  void _cambiarDias(String valor) {
    _dias = valor;
    _cambiar(_precio.copyWith(diasEntrega: int.tryParse(valor) ?? 0));
  }

  void _cambiarImporte(String valor) {
    _importe = valor;
    _cambiar(_precio.copyWith(importe: double.tryParse(valor) ?? 0));
  }

  /// Aplica un cambio y retira la marca de un campo en cuanto queda bien.
  void _cambiar(PrecioData precio) {
    setState(() {
      _precio = precio;

      if (_errores.isEmpty) return;

      final vigentes = validarPrecio(precio);
      _errores = {for (final campo in _errores.keys) campo: ?vigentes[campo]};
    });
  }

  Future<void> _guardar() async {
    final errores = validarPrecio(_precio);

    if (errores.isNotEmpty) {
      setState(() => _errores = errores);
      return;
    }

    final guardado = await ref
        .read(preciosViewModelProvider.notifier)
        .guardar(_precio);

    if (!mounted) return;

    if (guardado) {
      Navigator.of(context).pop(true);
      return;
    }

    await context.showErrorDialog(
      ref.read(preciosViewModelProvider).mensajeError,
    );
  }
}

/// La categoría a la que pertenece el concepto.
///
/// Sólo ofrece las activas: la base rechaza un concepto en una categoría dada
/// de baja.
class _SelectorCategoria extends StatelessWidget {
  const _SelectorCategoria({
    required this.categorias,
    required this.seleccionada,
    required this.onChanged,
    this.error,
  });

  final List<CategoriaData> categorias;
  final int seleccionada;
  final ValueChanged<CategoriaData> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        DropdownMenuBase<CategoriaData>(
          label: 'Categoría',
          width: _PrecioDialogState._anchoCampo,
          leadingIcon: const Icon(IconsManager.selectedCategoriasIcon),
          value: _seleccionada,
          items: [
            for (final categoria in categorias)
              DropdownMenuEntry<CategoriaData>(
                value: categoria,
                label: categoria.nombre,
              ),
          ],
          onChanged: (categoria) {
            if (categoria != null) onChanged(categoria);
          },
        ),
        // El desplegable no tiene dónde poner un error, así que va debajo con
        // el mismo aspecto que el de los campos de texto.
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  /// La categoría elegida dentro de la lista, para que el desplegable la
  /// reconozca: el concepto guarda su id, no la fila.
  CategoriaData? get _seleccionada {
    for (final categoria in categorias) {
      if (categoria.id == seleccionada) return categoria;
    }

    return null;
  }
}

/// La unidad en la que se cobra el concepto.
class _SelectorUnidad extends StatelessWidget {
  const _SelectorUnidad({required this.unidad, required this.onChanged});

  final UnitType unidad;
  final ValueChanged<UnitType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<UnitType>(
      label: 'Unidad',
      width: _PrecioDialogState._anchoCampo,
      leadingIcon: const Icon(Icons.widgets_rounded),
      value: unidad,
      items: [
        for (final opcion in UnitType.values)
          DropdownMenuEntry<UnitType>(value: opcion, label: opcion.value),
      ],
      onChanged: (opcion) => onChanged(opcion ?? unidad),
    );
  }
}
