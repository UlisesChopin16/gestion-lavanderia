import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/utils/icons_manager.dart';

/// El buscador de un listado: un filtro más, puesto entre los demás.
///
/// Vive en la pantalla y no dentro de la tarjeta del listado, igual que el
/// resto de los filtros: así cada listado decide cuánto ancho le da en la
/// rejilla —no todos buscan por lo mismo ni necesitan el mismo sitio— y la
/// tarjeta no tiene que saber nada de búsquedas.
///
/// ```dart
/// VCol(
///   cols: 12,
///   md: 5,
///   lg: 4,
///   child: SearchFilter(
///     label: 'Buscar categoría',
///     value: filtros.nombre,
///     onChanged: notifier.buscar,
///   ),
/// )
/// ```
///
/// Espera a que se deje de escribir antes de avisar: sin esa espera, teclear
/// "pantalón" lanza ocho consultas a la base.
class SearchFilter extends StatefulWidget {
  const SearchFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Buscar',
    this.debounce = const Duration(milliseconds: 300),
    this.onTap,
    this.grupoToque = EditableText,
  });

  /// Lo que el campo necesita para que se lea lo que uno escribe.
  ///
  /// Vive aquí para que cada pantalla se lo pase como `minWidth` a su columna
  /// sin repetir el número: por debajo de eso, el renglón de filtros se parte
  /// antes que aplastar el buscador.
  static const double anchoMinimo = 240;

  /// El texto por el que se está filtrando.
  ///
  /// Lo manda el listado, no el campo: por eso limpiar los filtros vacía
  /// también el buscador, y por eso un filtro guardado de la sesión anterior
  /// aparece escrito al abrir la pantalla.
  final String value;

  /// Recibe el texto una vez que se deja de escribir.
  final ValueChanged<String> onChanged;

  final String label;

  /// Cuánto se espera después de la última tecla antes de buscar.
  final Duration debounce;

  /// Cada toque sobre el campo, aunque ya tenga el foco.
  final GestureTapCallback? onTap;

  /// Con qué otros widgets comparte el campo su zona de toque.
  ///
  /// En escritorio, tocar fuera de un campo de texto le quita el foco. Un
  /// buscador que abre una lista flotante debajo pone aquí el mismo grupo que
  /// la lista: así tocar un resultado no cuenta como tocar fuera, y la lista
  /// no desaparece antes de que el toque llegue a su renglón.
  final Object grupoToque;

  @override
  State<SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  Timer? _espera;

  /// Lo último que este campo avisó hacia fuera.
  ///
  /// Distingue el eco de lo que uno acaba de escribir —que vuelve como
  /// [SearchFilter.value] un instante después— de un cambio de verdad. Sin
  /// esa diferencia, reponer el texto en cada reconstrucción borraría lo que
  /// se está tecleando mientras la espera corre.
  ///
  /// Se fija en [initState] y no al declararlo: un campo `late` se inicializa
  /// la primera vez que se lee, y la primera lectura ocurre dentro de
  /// [didUpdateWidget], cuando `widget` ya es el nuevo. Así se guardaba el
  /// valor que acababa de llegar y el cambio de fuera se daba por propio.
  String _avisado = '';

  @override
  void initState() {
    super.initState();
    _avisado = widget.value;
  }

  @override
  void didUpdateWidget(SearchFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value == oldWidget.value || widget.value == _avisado) return;

    // El texto cambió por fuera del campo: manda el listado y lo que hubiera
    // a medio escribir se descarta.
    _espera?.cancel();
    _avisado = widget.value;
    _controller.text = widget.value;
  }

  @override
  void dispose() {
    // El temporizador sobrevive al widget si no se cancela aquí: dispararía
    // una búsqueda sobre un estado ya desmontado.
    _espera?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _escribir(String texto) {
    _espera?.cancel();

    if (widget.debounce <= Duration.zero) {
      _avisar(texto);
      return;
    }

    _espera = Timer(widget.debounce, () => _avisar(texto));
  }

  void _avisar(String texto) {
    _avisado = texto;
    widget.onChanged(texto);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _escribir,
      onTap: widget.onTap,
      groupId: widget.grupoToque,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(IconsManager.search),
      ),
    );
  }
}
