import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/theme/color_row_theme.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/dialogs/formulario_precio.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/view_model/precios_view_model.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/precios/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';
import 'package:gestion_lavanderia/validations/precio_validation.dart';

/// Un cambio al formulario: recibe el de ahora y devuelve el nuevo.
typedef CambioFormulario = FormularioPrecio Function(FormularioPrecio actual);

/// El formulario de un concepto de ropa, para darlo de alta o editarlo.
///
/// Se lee de arriba abajo en el orden en que se piensa: qué es —nombre—, en
/// qué categorías se ofrece, cómo se mide —tamaño y unidad— y cuánto cuesta.
///
/// En un alta se pueden elegir varias categorías: el mismo concepto se crea
/// en cada una, con su propio precio. Los precios van al final en una tabla,
/// un renglón por categoría, rayados como los listados para que el importe
/// de una no se confunda con el de la de junto.
///
/// Se cierra devolviendo cuántos conceptos guardó, o `null` si se canceló. Si
/// alguno ya existe —misma categoría, mismo tamaño, mismo nombre— la base lo
/// rechaza, no se guarda ninguno y el diálogo se queda abierto.
class PrecioDialog extends ConsumerStatefulWidget {
  const PrecioDialog({super.key, this.precio});

  /// El concepto que se edita, o `null` para un alta.
  final PrecioData? precio;

  @override
  ConsumerState<PrecioDialog> createState() => _PrecioDialogState();
}

class _PrecioDialogState extends ConsumerState<PrecioDialog> {
  late FormularioPrecio _formulario = widget.precio == null
      ? const FormularioPrecio.alta()
      : FormularioPrecio.edicion(widget.precio!);

  /// Si ya se intentó guardar: antes de eso los campos vacíos no se marcan,
  /// porque nadie quiere ver errores en un formulario recién abierto.
  bool _mostrarErrores = false;

  static const double _anchoMaximo = 560;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(preciosViewModelProvider);
    final formulario = _formulario;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoMaximo),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Encabezado(
                  titulo: formulario.esAlta ? 'Nuevo concepto de ropa' : 'Editar concepto',
                ),
                Flexible(
                  child: _Campos(
                    formulario: formulario,
                    disponibles: _disponibles(estado.categoriasActivas),
                    mostrarErrores: _mostrarErrores,
                    onCambiar: _cambiar,
                    onListo: _guardar,
                  ),
                ),
                _Pie(etiqueta: _etiquetaGuardar, onGuardar: _guardar),
              ],
            ),
            if (estado.cargando)
              const Positioned.fill(
                child: AbsorbPointer(child: Center(child: CircularProgressIndicator())),
              ),
          ],
        ),
      ),
    );
  }

  /// Las categorías que se pueden elegir: las vigentes y, al editar, también
  /// la del concepto aunque se haya dado de baja, para que se vea cuál es.
  List<CategoriaData> _disponibles(List<CategoriaData> activas) {
    final original = widget.precio;
    if (original == null || activas.any((c) => c.id == original.categoriaId)) {
      return activas;
    }

    return [_formulario.categorias.first, ...activas];
  }

  String get _etiquetaGuardar {
    final cuantos = _formulario.categorias.length;

    if (!_formulario.esAlta) return 'Guardar cambios';

    return cuantos > 1 ? 'Guardar $cuantos conceptos' : 'Guardar';
  }

  /// Aplica [cambio] sobre el formulario de ahora, no sobre el que había
  /// cuando se dibujó el campo: dos cambios antes de que se vuelva a dibujar
  /// —escribir y tocar una categoría en el mismo instante— no se pisan.
  void _cambiar(CambioFormulario cambio) {
    setState(() => _formulario = cambio(_formulario));
  }

  /// Guarda, o marca lo que falta.
  Future<void> _guardar() async {
    final formulario = _formulario;

    if (!formulario.completo) {
      setState(() => _mostrarErrores = true);
      return;
    }

    final notifier = ref.read(preciosViewModelProvider.notifier);
    final conceptos = formulario.conceptos;
    final guardado = formulario.esAlta
        ? await notifier.guardarVarios(conceptos)
        : await notifier.guardar(conceptos.single);

    if (!mounted) return;

    if (guardado) {
      Navigator.of(context).pop(conceptos.length);
      return;
    }

    await context.showErrorDialog(ref.read(preciosViewModelProvider).mensajeError);
  }
}

/// El icono y el título.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        spacing: 8,
        children: [
          Icon(IconsManager.clotheIcon, color: theme.colorScheme.secondary),
          Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// Todo lo que se captura: lo que el concepto es en todas sus categorías y,
/// al final, el precio en cada una.
class _Campos extends StatelessWidget {
  const _Campos({
    required this.formulario,
    required this.disponibles,
    required this.mostrarErrores,
    required this.onCambiar,
    required this.onListo,
  });

  final FormularioPrecio formulario;
  final List<CategoriaData> disponibles;
  final bool mostrarErrores;
  final ValueChanged<CambioFormulario> onCambiar;

  /// Enter en un campo de precio: lo mismo que el botón de guardar.
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    final errores = mostrarErrores ? formulario.erroresComunes : const <CampoPrecio, String>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          FormTextField(
            value: formulario.nombre,
            onChanged: (nombre) => onCambiar((actual) => actual.conNombre(nombre)),
            autofocus: formulario.esAlta,
            label: 'Nombre del concepto',
            hint: 'Playera, Pantalón, Sábana',
            icon: IconsManager.clotheIcon,
            errorText: errores[CampoPrecio.nombreConcepto],
          ),
          _Categorias(
            disponibles: disponibles,
            formulario: formulario,
            error: errores[CampoPrecio.categoria],
            onAlternar: (categoria) => onCambiar((actual) => actual.alternarCategoria(categoria)),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: SelectorTamano(
                  tamano: formulario.tamano,
                  onChanged: (tamano) =>
                      onCambiar((actual) => actual.conTamano(tamano ?? ClotheSizeType.emptySize)),
                ),
              ),
              Expanded(
                child: _SelectorUnidad(
                  unidad: formulario.unidad,
                  onChanged: (unidad) => onCambiar((actual) => actual.conUnidad(unidad)),
                ),
              ),
            ],
          ),
          _Precios(
            formulario: formulario,
            mostrarErrores: mostrarErrores,
            onCambiar: onCambiar,
            onListo: onListo,
          ),
        ],
      ),
    );
  }
}

/// Las categorías como etiquetas que se prenden y se apagan.
///
/// Etiquetas y no un desplegable: se ven todas de un vistazo, se elige más
/// de una sin abrir y cerrar un menú, y queda a la vista qué se eligió.
class _Categorias extends StatelessWidget {
  const _Categorias({
    required this.disponibles,
    required this.formulario,
    required this.error,
    required this.onAlternar,
  });

  final List<CategoriaData> disponibles;
  final FormularioPrecio formulario;
  final String? error;
  final ValueChanged<CategoriaData> onAlternar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;

    return _Seccion(
      titulo: formulario.esAlta ? 'Categorías' : 'Categoría',
      ayuda: formulario.esAlta ? 'Elige una o varias. Cada una tendrá su propio precio.' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final categoria in disponibles)
                FilterChip(
                  label: Text(categoria.nombre),
                  tooltip: 'Entrega en ${categoria.diasFormato}',
                  selected: formulario.estaElegida(categoria),
                  // Al editar es una sola: la marca de "elegida" sobra, el
                  // color ya lo dice.
                  showCheckmark: formulario.esAlta,
                  onSelected: (_) => onAlternar(categoria),
                ),
            ],
          ),
          if (error != null)
            Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}

/// El precio del concepto en cada categoría elegida.
class _Precios extends StatelessWidget {
  const _Precios({
    required this.formulario,
    required this.mostrarErrores,
    required this.onCambiar,
    required this.onListo,
  });

  final FormularioPrecio formulario;
  final bool mostrarErrores;
  final ValueChanged<CambioFormulario> onCambiar;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    final categorias = formulario.categorias;
    final primera = categorias.firstOrNull;
    final importePrimera = primera == null ? '' : formulario.precioDe(primera).importe;
    // Copiar sólo sirve si hay de dónde y a dónde: un importe escrito en la
    // primera y alguna otra con uno distinto.
    final puedeCopiar =
        importePrimera.isNotEmpty &&
        categorias.any((c) => formulario.precioDe(c).importe != importePrimera);

    return _Seccion(
      titulo: formulario.variasCategorias ? 'Precios' : 'Precio',
      ayuda: formulario.esAlta && primera != null
          ? 'Los días vienen de la categoría; cámbialos si este concepto '
                'tarda distinto.'
          : null,
      // La tabla crece y se encoge al elegir categorías: sin animación, el
      // diálogo daría un salto con cada etiqueta.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: primera == null
            ? const _SinCategorias()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  _TablaPrecios(
                    formulario: formulario,
                    mostrarErrores: mostrarErrores,
                    onCambiar: onCambiar,
                    onListo: onListo,
                  ),
                  if (puedeCopiar)
                    TextButton.icon(
                      onPressed: () => onCambiar((actual) => actual.conImporteEnTodas(primera)),
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      label: Text(
                        'Usar el importe de ${primera.nombre} '
                        '(\$$importePrimera) en todas',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Antes de elegir categoría: el lugar de los precios, y qué falta para
/// llenarlo.
class _SinCategorias extends StatelessWidget {
  const _SinCategorias();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.sell_outlined, color: scheme.onSurfaceVariant),
          Expanded(
            child: Text(
              'Elige una categoría para ponerle precio.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un renglón por categoría con su importe y sus días, en cuadrícula.
///
/// Las columnas alineadas dejan comparar los importes de un vistazo, y el
/// rayado —el mismo de los listados— separa un renglón del otro. Los campos
/// van sin etiqueta: la dice el encabezado.
class _TablaPrecios extends StatelessWidget {
  const _TablaPrecios({
    required this.formulario,
    required this.mostrarErrores,
    required this.onCambiar,
    required this.onListo,
  });

  final FormularioPrecio formulario;
  final bool mostrarErrores;
  final ValueChanged<CambioFormulario> onCambiar;
  final VoidCallback onListo;

  static const _radio = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rayado = ColorRowTheme.of(context);

    return Theme(
      // En una columna angosta el error no cabe en un renglón.
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(errorMaxLines: 3),
      ),
      child: ClipRRect(
        borderRadius: _radio,
        child: Table(
          border: TableBorder.all(color: scheme.outlineVariant, borderRadius: _radio),
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.primary),
              children: const [
                _Titulo('Categoría'),
                _Titulo('Importe'),
                _Titulo('Días de entrega'),
              ],
            ),
            for (final (indice, categoria) in formulario.categorias.indexed)
              TableRow(
                key: ValueKey(categoria.id),
                decoration: BoxDecoration(color: rayado.colorForRow(indice)),
                children: [
                  _CeldaCategoria(categoria: categoria),
                  _CeldaImporte(
                    formulario: formulario,
                    categoria: categoria,
                    mostrarErrores: mostrarErrores,
                    onCambiar: onCambiar,
                    onListo: onListo,
                  ),
                  _CeldaDias(
                    formulario: formulario,
                    categoria: categoria,
                    mostrarErrores: mostrarErrores,
                    onCambiar: onCambiar,
                    onListo: onListo,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// El encabezado de una columna de la tabla de precios, con los colores del
/// de los listados.
class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        texto,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// El nombre de la categoría y los días que tarda de por sí.
class _CeldaCategoria extends StatelessWidget {
  const _CeldaCategoria({required this.categoria});

  final CategoriaData categoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(categoria.nombre, style: theme.textTheme.titleSmall),
          Text(
            'Entrega en ${categoria.diasFormato}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// El importe del concepto en [categoria].
class _CeldaImporte extends StatelessWidget {
  const _CeldaImporte({
    required this.formulario,
    required this.categoria,
    required this.mostrarErrores,
    required this.onCambiar,
    required this.onListo,
  });

  final FormularioPrecio formulario;
  final CategoriaData categoria;
  final bool mostrarErrores;
  final ValueChanged<CambioFormulario> onCambiar;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FormTextField(
        // Uno por categoría: el mismo campo no debe arrastrar el texto de
        // una categoría a otra.
        key: ValueKey('importe-${categoria.id}'),
        value: formulario.precioDe(categoria).importe,
        onChanged: (importe) => onCambiar((actual) => actual.conImporte(categoria, importe)),
        hint: '00.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        errorText: mostrarErrores ? formulario.erroresDe(categoria)[CampoPrecio.importe] : null,
        onSubmitted: (_) => onListo(),
      ),
    );
  }
}

/// Los días de entrega del concepto en [categoria].
class _CeldaDias extends StatelessWidget {
  const _CeldaDias({
    required this.formulario,
    required this.categoria,
    required this.mostrarErrores,
    required this.onCambiar,
    required this.onListo,
  });

  final FormularioPrecio formulario;
  final CategoriaData categoria;
  final bool mostrarErrores;
  final ValueChanged<CambioFormulario> onCambiar;
  final VoidCallback onListo;

  static const _digitosDias = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FormTextField(
        key: ValueKey('dias-${categoria.id}'),
        value: formulario.precioDe(categoria).dias,
        onChanged: (dias) => onCambiar((actual) => actual.conDias(categoria, dias)),
        hint: '1, 2, 3...',
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_digitosDias),
        ],
        errorText: mostrarErrores ? formulario.erroresDe(categoria)[CampoPrecio.diasEntrega] : null,
        onSubmitted: (_) => onListo(),
      ),
    );
  }
}

/// Un título chico con su contenido debajo.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child, this.ayuda});

  final String titulo;
  final String? ayuda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ayuda = this.ayuda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(titulo, style: theme.textTheme.titleSmall),
            if (ayuda != null)
              Text(
                ayuda,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        child,
      ],
    );
  }
}

/// Cancelar y guardar.
class _Pie extends StatelessWidget {
  const _Pie({required this.etiqueta, required this.onGuardar});

  final String etiqueta;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      // En Wrap: en una ventana angosta los dos botones bajan de renglón en
      // lugar de desbordarse.
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: scheme.error)),
          ),
          FilledButton.icon(
            onPressed: onGuardar,
            icon: const Icon(Icons.check_rounded),
            label: Text(etiqueta),
          ),
        ],
      ),
    );
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
