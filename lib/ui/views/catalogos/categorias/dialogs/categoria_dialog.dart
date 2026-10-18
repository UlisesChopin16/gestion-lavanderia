import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogs.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/categorias/view_model/categorias_view_model.dart';
import 'package:gestion_lavanderia/validations/categoria_validation.dart';

/// El formulario de una categoría de ropa, para darla de alta o editarla.
///
/// Se cierra devolviendo `true` cuando se guardó. Un nombre repetido lo
/// rechaza la base —es la única que ve también las categorías dadas de baja—,
/// y entonces el diálogo se queda abierto con el motivo a la vista.
class CategoriaDialog extends ConsumerStatefulWidget {
  const CategoriaDialog({super.key, this.categoria});

  /// La categoría que se edita, o `null` para un alta.
  final CategoriaServicioEntry? categoria;

  @override
  ConsumerState<CategoriaDialog> createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends ConsumerState<CategoriaDialog> {
  late String _nombre = widget.categoria?.nombre ?? '';
  late String _diasEntrega = '${widget.categoria?.diasEntrega ?? _diasAlta}';

  Map<CampoCategoria, String> _errores = const {};

  /// Los días con los que nace una categoría: lo más común es entregar al día
  /// siguiente.
  static const _diasAlta = 1;
  static const _digitosDias = 3;
  static const _anchoContenido = 360.0;

  bool get _esAlta => widget.categoria == null;

  int get _dias => int.tryParse(_diasEntrega) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cargando = ref.watch(
      categoriasViewModelProvider.select((estado) => estado.cargando),
    );

    return Stack(
      children: [
        BaseDialog(
          title: _esAlta ? 'Nueva categoría de ropa' : 'Editar categoría',
          icon: const Icon(Icons.category_rounded),
          actionText: 'Guardar',
          closeOnAction: false,
          onActionPressed: _guardar,
          content: SizedBox(
            width: _anchoContenido,
            child: SingleChildScrollView(
              child: Column(
                spacing: 15,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormTextField(
                    value: _nombre,
                    onChanged: (valor) => _cambiar(() => _nombre = valor),
                    autofocus: true,
                    label: 'Nombre de la categoría',
                    hint: 'Ropa de cama, Planchado, Tintorería',
                    icon: Icons.category_rounded,
                    errorText: _errores[CampoCategoria.nombre],
                  ),
                  FormTextField(
                    value: _diasEntrega,
                    onChanged: (valor) => _cambiar(() => _diasEntrega = valor),
                    label: 'Días de entrega',
                    hint: '1, 2, 3...',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_digitosDias),
                    ],
                    errorText: _errores[CampoCategoria.diasEntrega],
                    onSubmitted: (_) => _guardar(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (cargando) const AbsorbPointer(child: BlockProgress()),
      ],
    );
  }

  /// Aplica un cambio y retira la marca de un campo en cuanto queda bien.
  void _cambiar(VoidCallback cambio) {
    setState(() {
      cambio();

      if (_errores.isEmpty) return;

      final vigentes = _validar();
      _errores = {for (final campo in _errores.keys) campo: ?vigentes[campo]};
    });
  }

  Map<CampoCategoria, String> _validar() =>
      validarCategoria(nombre: _nombre, diasEntrega: _dias);

  Future<void> _guardar() async {
    final errores = _validar();

    if (errores.isNotEmpty) {
      setState(() => _errores = errores);
      return;
    }

    if (!await _confirmarCambioDeDias()) return;

    if (!mounted) return;

    final notifier = ref.read(categoriasViewModelProvider.notifier);

    final guardado = await notifier.guardar(
      id: widget.categoria?.id,
      nombre: _nombre,
      diasEntrega: _dias,
    );

    if (!mounted) return;

    if (guardado) {
      Navigator.of(context).pop(true);
      return;
    }

    await context.showErrorDialog(
      ref.read(categoriasViewModelProvider).mensajeError,
    );
  }

  /// Avisa de que los conceptos de la categoría heredarán los días nuevos.
  ///
  /// Los días de un concepto son los de su categoría, así que el cambio se
  /// propaga siempre; lo que se pregunta no es si propagarlo, sino si de
  /// verdad se quiere cambiar sabiendo a cuántos conceptos alcanza.
  Future<bool> _confirmarCambioDeDias() async {
    final categoria = widget.categoria;

    if (categoria == null || categoria.diasEntrega == _dias) return true;

    return context.showWarningDialog(
      message:
          'Los conceptos de "${categoria.nombre}" pasarán también a $_dias '
          'día(s) de entrega. ¿Continuar?',
    );
  }
}
