import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/ui/views/configuracion_empresa/view_model/configuracion_empresa_view_model.dart';

/// El logo de la empresa, con el que se imprime el ticket.
///
/// Al pasar el cursor por encima aparece la invitación a cambiarlo, de modo que
/// se entienda que la imagen es un botón. En sólo lectura no responde.
class LogoPicker extends ConsumerStatefulWidget {
  const LogoPicker({super.key, required this.ancho, required this.alto});

  final double ancho;
  final double alto;

  @override
  ConsumerState<LogoPicker> createState() => _LogoPickerState();
}

class _LogoPickerState extends ConsumerState<LogoPicker> {
  bool _conCursorEncima = false;

  static final _radio = BorderRadius.circular(15);

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(configuracionEmpresaViewModelProvider.notifier);
    final (logo, editable) = ref.watch(
      configuracionEmpresaViewModelProvider.select(
        (estado) => (estado.empresa.logo, estado.editable),
      ),
    );

    final scheme = Theme.of(context).colorScheme;
    final tieneLogo = logo != null && logo.isNotEmpty;

    return MouseRegion(
      onEnter: editable ? (_) => _cambiarCursor(true) : null,
      onExit: editable ? (_) => _cambiarCursor(false) : null,
      child: Tooltip(
        message: editable
            ? 'Selecciona una imagen para el logo'
            : 'Habilita la edición para cambiar el logo',
        child: InkWell(
          onTap: editable ? notifier.cambiarLogo : null,
          borderRadius: _radio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: widget.alto,
                width: widget.ancho,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: _radio,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: tieneLogo
                    ? _Imagen(ruta: logo)
                    : const _Invitacion(texto: 'Subir logo'),
              ),
              // El velo sólo aparece con el cursor encima y sobre un logo ya
              // elegido: sin imagen debajo taparía la invitación que ya está a
              // la vista.
              if (tieneLogo)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _conCursorEncima ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: _radio,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const _Invitacion(
                            texto: 'Cambiar logo',
                            sobreVelo: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _cambiarCursor(bool encima) {
    setState(() => _conCursorEncima = encima);
  }
}

/// La imagen del logo guardada en disco.
class _Imagen extends StatelessWidget {
  const _Imagen({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(ruta),
      fit: BoxFit.contain,
      // El archivo puede haber desaparecido —otra computadora, una carpeta
      // movida—: en ese caso se vuelve a la invitación en lugar de dejar un
      // hueco gris con una excepción en la consola.
      errorBuilder: (context, error, stackTrace) => const _Invitacion(
        texto: 'No se encontró el logo. Toca para elegir otro',
      ),
    );
  }
}

class _Invitacion extends StatelessWidget {
  const _Invitacion({required this.texto, this.sobreVelo = false});

  final String texto;

  /// Si va encima del velo oscuro, donde el color del tema no contrasta.
  final bool sobreVelo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sobreVelo ? Colors.white : theme.colorScheme.primary;

    return Center(
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file, color: color, size: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
