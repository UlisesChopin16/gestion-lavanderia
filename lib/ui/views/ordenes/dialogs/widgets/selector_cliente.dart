import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/widgets/paso_titulo.dart';

/// A quién es la orden: se busca, y si no está, se da de alta sin salir.
///
/// Mientras no hay nadie elegido se ve el buscador. Al tocarlo se despliega
/// debajo una lista flotante —los clientes recientes, o lo que va
/// encontrando en cuanto se escribe—, encima del resto del alta: así la lista
/// no empuja el catálogo ni lo deja fuera de la vista. En cuanto se
/// elige, el buscador se recoge y queda la ficha del cliente. Es un paso que
/// se hace una vez por orden, así que no tiene por qué seguir ocupando sitio
/// después.
///
/// La búsqueda es por nombre, teléfono o correo a la vez: en el mostrador se
/// tiene uno de los tres, no se sabe cuál de antemano.
class SelectorCliente extends StatelessWidget {
  const SelectorCliente({
    super.key,
    required this.busqueda,
    required this.encontrados,
    required this.cliente,
    required this.onBuscar,
    required this.onElegir,
    required this.onQuitar,
    required this.onRegistrar,
  });

  /// Lo que se escribió en el buscador.
  final String busqueda;

  /// Lo que devolvió la base para esa búsqueda.
  final Iterable<ClienteData> encontrados;

  /// El cliente elegido, o `null` mientras no hay ninguno.
  final ClienteData? cliente;

  final ValueChanged<String> onBuscar;
  final ValueChanged<ClienteData> onElegir;
  final VoidCallback onQuitar;

  /// Abre el alta de un cliente nuevo.
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    final cliente = this.cliente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const PasoTitulo(numero: '1', titulo: 'Cliente'),
        if (cliente != null)
          _Elegido(cliente: cliente, onQuitar: onQuitar)
        else
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _Buscador(
                  busqueda: busqueda,
                  encontrados: encontrados,
                  onBuscar: onBuscar,
                  onElegir: onElegir,
                  onRegistrar: onRegistrar,
                ),
              ),
              // El alta está siempre a mano y no sólo cuando la búsqueda no
              // encuentra nada: con un cliente nuevo se sabe de antemano, y
              // obligarle a buscar primero es un paso de más.
              IconButton.filledTonal(
                onPressed: onRegistrar,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: 'Registrar un cliente nuevo',
              ),
            ],
          ),
      ],
    );
  }
}

/// El campo de búsqueda con sus resultados flotando debajo.
///
/// Los resultados van en un [OverlayPortal]: se dibujan en la capa de encima
/// del diálogo, pegados al campo con un [LayerLink], y miden lo que el campo.
/// Se ven mientras el campo tiene el foco, escrito algo o no; se esconden al
/// tocar fuera o con Esc, y vuelven al tocar el campo o al seguir escribiendo.
///
/// El campo y la lista comparten grupo de toque —el `groupId` del campo de
/// texto—: en escritorio, tocar fuera de un campo le quita el foco, y sin el
/// grupo el toque sobre un cliente escondía la lista antes de elegirlo.
class _Buscador extends StatefulWidget {
  const _Buscador({
    required this.busqueda,
    required this.encontrados,
    required this.onBuscar,
    required this.onElegir,
    required this.onRegistrar,
  });

  final String busqueda;
  final Iterable<ClienteData> encontrados;
  final ValueChanged<String> onBuscar;
  final ValueChanged<ClienteData> onElegir;
  final VoidCallback onRegistrar;

  @override
  State<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<_Buscador> {
  /// El portal se muestra una vez y se queda: lo que cambia es si dibuja algo.
  /// Mostrarlo y esconderlo según el estado obligaría a hacerlo fuera del
  /// `build`, y lo que dibuja ya depende de lo mismo que decidiría eso.
  final _portal = OverlayPortalController()..show();
  final _enlace = LayerLink();

  /// Lo que comparten el campo y la lista para que tocar uno no cuente como
  /// tocar fuera del otro.
  final _grupo = Object();

  bool _conFoco = false;

  /// Si se cerró la lista a propósito —Esc, un toque fuera— sin quitar el
  /// foco. Se olvida al tocar el campo o al escribir otra cosa.
  bool _cerrada = false;

  /// Lo que la lista mide como mucho: unos cinco renglones. Pasado eso se
  /// recorre.
  static const double _altoMaximo = 280;

  bool get _abierta => _conFoco && !_cerrada;

  @override
  void didUpdateWidget(_Buscador oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busqueda != widget.busqueda) _cerrada = false;
  }

  void _cerrar() {
    if (_abierta) setState(() => _cerrada = true);
  }

  void _reabrir() {
    if (_cerrada) setState(() => _cerrada = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;

        return OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) {
            if (!_abierta) return const SizedBox.shrink();

            return Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: _enlace,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                offset: const Offset(0, 4),
                child: TapRegion(
                  groupId: _grupo,
                  child: SizedBox(
                    width: ancho,
                    child: _ListaFlotante(
                      altoMaximo: _altoMaximo,
                      child: widget.encontrados.isEmpty
                          ? _SinResultados(
                              busqueda: widget.busqueda,
                              onRegistrar: widget.onRegistrar,
                            )
                          : _Resultados(
                              encontrados: widget.encontrados,
                              recientes: widget.busqueda.trim().isEmpty,
                              onElegir: widget.onElegir,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: CompositedTransformTarget(
            link: _enlace,
            child: TapRegion(
              groupId: _grupo,
              onTapOutside: (_) => _cerrar(),
              // Esc cierra la lista antes que el diálogo: es lo que está
              // encima. Sin la lista a la vista, Esc sigue de largo.
              child: Actions(
                actions: {DismissIntent: _CerrarLista(this)},
                child: Focus(
                  onFocusChange: (foco) => setState(() => _conFoco = foco),
                  child: SearchFilter(
                    label: 'Buscar por nombre, teléfono o correo',
                    value: widget.busqueda,
                    onChanged: widget.onBuscar,
                    onTap: _reabrir,
                    grupoToque: _grupo,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Esc con la lista abierta: la cierra. Con la lista cerrada no está
/// habilitada, y Esc llega al diálogo como siempre.
class _CerrarLista extends DismissAction {
  _CerrarLista(this._buscador);

  final _BuscadorState _buscador;

  @override
  bool isEnabled(DismissIntent intent) => _buscador._abierta;

  @override
  void invoke(DismissIntent intent) => _buscador._cerrar();
}

/// La caja de la lista flotante: con contorno y una sombra suave, porque está
/// encima de algo. Una sombra fuerte, sobre el fondo oscuro, se veía como un
/// marco negro grueso.
class _ListaFlotante extends StatelessWidget {
  const _ListaFlotante({required this.altoMaximo, required this.child});

  final double altoMaximo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 2,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altoMaximo),
        child: child,
      ),
    );
  }
}

/// El cliente ya elegido, con lo que hace falta para reconocerlo.
class _Elegido extends StatelessWidget {
  const _Elegido({required this.cliente, required this.onQuitar});

  final ClienteData cliente;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary,
            child: Icon(Icons.person_rounded, color: scheme.onPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombreCompleto,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  cliente.telefono,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onQuitar, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}

class _Resultados extends StatelessWidget {
  const _Resultados({
    required this.encontrados,
    required this.recientes,
    required this.onElegir,
  });

  final Iterable<ClienteData> encontrados;

  /// Si son los recientes y no lo que se buscó: entonces llevan su título,
  /// para que no parezca que la búsqueda encontró a esos.
  final bool recientes;

  final ValueChanged<ClienteData> onElegir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clientes = encontrados.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recientes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(
              'Clientes recientes',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: clientes.length,
            itemBuilder: (context, indice) {
              final cliente = clientes[indice];

              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(cliente.nombreCompleto),
                subtitle: Text('${cliente.telefono} · ${cliente.correo}'),
                onTap: () => onElegir(cliente),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Cuando la búsqueda no encuentra a nadie —o, sin nada escrito, cuando
/// todavía no hay clientes—: el camino es darlo de alta.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.busqueda, required this.onRegistrar});

  final String busqueda;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.person_search_rounded, color: theme.colorScheme.outline),
          Expanded(
            child: Text(
              busqueda.trim().isEmpty
                  ? 'Todavía no hay clientes registrados.'
                  : 'Nadie coincide con "${busqueda.trim()}".',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onRegistrar,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}
