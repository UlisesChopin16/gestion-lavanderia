import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/block_progress.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/title_container.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/dialogs/password_dialog.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/widgets/widgets.dart';
import 'package:gestion_lavanderia/utils/constants_manager.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// Los datos de la lavandería: contacto, logo, color, contraseña, dirección y
/// la cuenta de correo desde la que se envían los tickets.
///
/// Es la misma pantalla la primera vez y todas las siguientes. Cuando ya hay
/// configuración guardada arranca protegida —se desbloquea con la contraseña—,
/// porque está pensada para una computadora de mostrador a la que tiene acceso
/// cualquiera.
class ConfiguracionEmpresaView extends ConsumerWidget {
  const ConfiguracionEmpresaView({super.key});

  static const _altoLogo = 260.0;

  /// Lo que separa la tarjeta de las orillas, y su contenido del borde de la
  /// tarjeta. En una ventana angosta se recortan todavía más: ahí cada píxel
  /// hace falta para los campos.
  static const _margenAmplio = 16.0;
  static const _margenAngosto = 8.0;
  static const _rellenoAmplio = 12.0;
  static const _rellenoAngosto = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (cargando, editable, esAlta, mensajeError) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (
          estado.cargando,
          estado.editable,
          estado.esAlta,
          estado.mensajeError,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // En una ventana angosta el margen es papel desperdiciado: lo que no se
        // gasta en orillas es ancho para los campos.
        final esAngosta = constraints.maxWidth < ConstantsManager.smallScreen;
        final margen = esAngosta ? _margenAngosto : _margenAmplio;
        final relleno = esAngosta ? _rellenoAngosto : _rellenoAmplio;

        // El ancho de los campos se reparte el espacio que queda: con un
        // ancho fijo, una ventana angosta los desbordaba.
        final disponible = constraints.maxWidth - (margen + relleno) * 2;
        final ancho = MedidasFormulario.anchoCampo(disponible);

        // La tarjeta mide lo que lleva dentro. Antes se estiraba hasta un
        // ancho fijo y, cuando ahí sólo cabía una columna de campos, el ancho
        // de la otra se quedaba como hueco a los lados.
        final anchoTarjeta =
            MedidasFormulario.anchoContenido(disponible) + relleno * 2;

        return Stack(
          children: [
            Scaffold(
              body: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(margen),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: anchoTarjeta),
                    child: Card(
                      // Sin el margen de omisión de `Card`: la separación con
                      // las orillas la decide el relleno de arriba, en un solo
                      // lugar.
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(relleno),
                        child: Column(
                          spacing: MedidasFormulario.separacion,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const TitleContainer(
                              title: 'Configuración de la empresa',
                              icon: IconsManager.selectedEmpresaIcon,
                            ),
                            if (mensajeError.isNotEmpty)
                              _Aviso(mensaje: mensajeError),
                            if (!editable) const _BarraProtegida(),
                            _Encabezado(anchoCampo: ancho, altoLogo: _altoLogo),
                            const _Separador(titulo: 'Dirección de la empresa'),
                            DatosDireccionForm(anchoCampo: ancho),
                            const _Separador(
                              titulo: 'Correo para enviar tickets',
                            ),
                            DatosCorreoForm(anchoCampo: ancho),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              floatingActionButton: editable
                  ? _BotonesEdicion(esAlta: esAlta, compacto: esAngosta)
                  : null,
            ),
            // Mientras se lee o se guarda, la pantalla no acepta nada: un
            // segundo toque en guardar escribiría dos veces.
            if (cargando) const AbsorbPointer(child: BlockProgress()),
          ],
        );
      },
    );
  }
}

/// El logo y el color a la izquierda, los datos de contacto a la derecha; uno
/// debajo del otro cuando no caben.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.anchoCampo, required this.altoLogo});

  final double anchoCampo;
  final double altoLogo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MedidasFormulario.separacion,
      runSpacing: MedidasFormulario.separacion,
      alignment: WrapAlignment.center,
      children: [
        Column(
          spacing: MedidasFormulario.separacion,
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoPicker(ancho: anchoCampo, alto: altoLogo),
            PaletaColores(ancho: anchoCampo),
          ],
        ),
        DatosEmpresaForm(anchoCampo: anchoCampo),
      ],
    );
  }
}

/// Explica por qué los campos están deshabilitados y ofrece desbloquearlos.
///
/// La versión anterior envolvía el formulario en un `IgnorePointer`: los campos
/// se veían normales y simplemente no respondían al toque.
class _BarraProtegida extends ConsumerWidget {
  const _BarraProtegida();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: scheme.onSecondaryContainer),
              // Flexible, o el texto reclama su ancho natural y desborda el
              // renglón en una ventana angosta en lugar de partirse en dos.
              Flexible(
                child: Text(
                  'Los datos están protegidos.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
          FilledButton.tonalIcon(
            onPressed: () => _desbloquear(context),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Future<void> _desbloquear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );
  }
}

/// Guardar y, cuando hay algo guardado a lo que volver, cancelar.
class _BotonesEdicion extends ConsumerWidget {
  const _BotonesEdicion({required this.esAlta, required this.compacto});

  /// En un alta no se ofrece cancelar: no hay nada a lo que regresar y el
  /// botón sólo borraría lo que se acaba de capturar.
  final bool esAlta;

  /// Si el botón de guardar va sin su texto.
  ///
  /// En una ventana angosta "Guardar datos" no cabe y el renglón de botones se
  /// desborda; con el icono solo, lo que dice el botón se consulta en su globo
  /// de ayuda.
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (!esAlta)
          FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Descartar los cambios',
            onPressed: notifier.cancelarEdicion,
            child: const Icon(Icons.close_rounded),
          ),
        if (compacto)
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Guardar datos',
            onPressed: () => _guardar(context, ref),
            child: const Icon(Icons.save_rounded),
          )
        else
          FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _guardar(context, ref),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar datos'),
          ),
      ],
    );
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final resultado = await notifier.guardar();

    if (!context.mounted) return;

    switch (resultado) {
      case ResultadoGuardado.guardado:
        await context.showSuccessDialog(
          'Los datos de la empresa se guardaron correctamente.',
        );
      // Los campos marcados y el aviso de la pantalla ya explican qué pasó:
      // un diálogo encima taparía justo lo que hay que leer.
      case ResultadoGuardado.camposInvalidos:
      case ResultadoGuardado.error:
        return;
    }
  }
}

/// El título de una sección del formulario, entre dos líneas.
class _Separador extends StatelessWidget {
  const _Separador({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      spacing: 10,
      children: [
        const Expanded(child: Divider()),
        Flexible(
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Lo último que falló, a la vista y no en un diálogo que se cierra.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
