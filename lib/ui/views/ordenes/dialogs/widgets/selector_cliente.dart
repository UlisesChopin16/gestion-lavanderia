import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/models/data/clientes/cliente_data.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/ordenes/dialogs/widgets/paso_titulo.dart';

/// A quién es la orden: se busca, y si no está, se da de alta sin salir.
///
/// Mientras no hay nadie elegido se ve el buscador con lo que va encontrando;
/// en cuanto se elige, el buscador se recoge y queda la ficha del cliente. Es
/// un paso que se hace una vez por orden, así que no tiene por qué seguir
/// ocupando sitio después.
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

  /// Lo que la lista de resultados mide como mucho: unos cuatro renglones.
  /// Pasado eso se recorre, en lugar de empujar al catálogo fuera de la vista.
  static const double _altoResultados = 196;

  bool get _sinResultados => busqueda.trim().isNotEmpty && encontrados.isEmpty;

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
        else ...[
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: SearchFilter(
                  label: 'Buscar por nombre, teléfono o correo',
                  value: busqueda,
                  onChanged: onBuscar,
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
          if (_sinResultados)
            _SinResultados(busqueda: busqueda, onRegistrar: onRegistrar)
          else if (encontrados.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _altoResultados),
              child: _Resultados(encontrados: encontrados, onElegir: onElegir),
            ),
        ],
      ],
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
  const _Resultados({required this.encontrados, required this.onElegir});

  final Iterable<ClienteData> encontrados;
  final ValueChanged<ClienteData> onElegir;

  @override
  Widget build(BuildContext context) {
    final clientes = encontrados.toList();

    return _Marco(
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
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
    );
  }
}

/// Cuando la búsqueda no encuentra a nadie: el camino es darlo de alta, así
/// que el botón dice a quién y no sólo "registrar".
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.busqueda, required this.onRegistrar});

  final String busqueda;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Marco(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            Icon(Icons.person_search_rounded, color: theme.colorScheme.outline),
            Expanded(
              child: Text(
                'Nadie coincide con "${busqueda.trim()}".',
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
      ),
    );
  }
}

class _Marco extends StatelessWidget {
  const _Marco({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
