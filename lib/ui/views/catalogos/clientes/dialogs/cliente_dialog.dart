import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_lavanderia/extensions/build_context_ext.dart';
import 'package:gestion_lavanderia/extensions/string_ext.dart';
import 'package:gestion_lavanderia/ui/shared/dialogs/dialogs.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';
import 'package:gestion_lavanderia/ui/views/catalogos/clientes/view_model/clientes_view_model.dart';
import 'package:gestion_lavanderia/utils/nombre_completo.dart';
import 'package:gestion_lavanderia/validations/cliente_validation.dart';

/// El formulario de un cliente, para darlo de alta o editarlo.
///
/// Es el mismo diálogo en los dos casos —sólo cambian el título y si los
/// campos nacen llenos—: antes eran dos archivos casi idénticos envolviendo el
/// mismo formulario.
///
/// Se cierra devolviendo `true` cuando se guardó. Si la base rechaza el
/// cliente —un teléfono que ya es de otro— se queda abierto con el motivo a la
/// vista, para corregir en lugar de volver a capturarlo todo.
class ClienteDialog extends ConsumerStatefulWidget {
  const ClienteDialog({super.key, this.cliente, this.busqueda = ''});

  /// El cliente que se edita, o `null` para un alta.
  final ClienteData? cliente;

  /// Lo que se escribió en el buscador del que vino este alta.
  ///
  /// Un alta que nace de una búsqueda sin resultados llega con ese dato ya
  /// puesto en el campo que le toca: el nombre repartido en nombres y
  /// apellidos, o el teléfono o el correo si eso fue lo que se tecleó. Se
  /// escribió una vez para buscar y no hay por qué escribirlo otra.
  ///
  /// Vacío en un alta que no viene de ningún buscador, y sin efecto cuando se
  /// está editando.
  final String busqueda;

  @override
  ConsumerState<ClienteDialog> createState() => _ClienteDialogState();
}

class _ClienteDialogState extends ConsumerState<ClienteDialog> {
  late String _nombres;
  late String _apellidos;
  late String _telefono;
  late String _correo;

  /// Los campos mal capturados, con el motivo de cada uno.
  ///
  /// Viven aquí y no en el estado de la pantalla porque pertenecen a esta
  /// captura: al cerrar el diálogo no queda nada que recordar.
  Map<CampoCliente, String> _errores = const {};

  static const _digitosTelefono = 10;
  static const _anchoContenido = 360.0;

  bool get _esAlta => widget.cliente == null;

  @override
  void initState() {
    super.initState();

    final cliente = widget.cliente;

    if (cliente != null) {
      _nombres = cliente.nombres;
      _apellidos = cliente.apellidos;
      _telefono = cliente.telefono;
      _correo = cliente.correo;

      return;
    }

    _llenarDesdeLaBusqueda();
  }

  /// Reparte lo que se tecleó en el buscador entre los campos del formulario.
  ///
  /// El buscador acepta las tres cosas —nombre, teléfono o correo—, así que
  /// aquí se decide cuál de ellas es: todo dígitos es un teléfono, con arroba
  /// es un correo, y lo demás es un nombre, que se parte en nombres y
  /// apellidos con la costumbre de aquí.
  ///
  /// Lo que salga es una conjetura y queda a la vista para corregirse: se
  /// precarga el formulario, no se da de alta a nadie.
  void _llenarDesdeLaBusqueda() {
    final busqueda = widget.busqueda.normalizeSpaces();

    _nombres = '';
    _apellidos = '';
    _telefono = '';
    _correo = '';

    if (busqueda.isEmpty) return;

    if (busqueda.isEmail) {
      _correo = busqueda;
      return;
    }

    if (busqueda.isOnlyNumbers) {
      // El campo del teléfono no admite más dígitos de los que mide, y el
      // valor inicial no pasa por sus formateadores.
      _telefono = busqueda.length > _digitosTelefono
          ? busqueda.substring(0, _digitosTelefono)
          : busqueda;

      return;
    }

    final nombre = NombreCompleto.repartir(busqueda);

    _nombres = nombre.nombres;
    _apellidos = nombre.apellidos;
  }

  @override
  Widget build(BuildContext context) {
    final cargando = ref.watch(
      clientesViewModelProvider.select((estado) => estado.cargando),
    );

    return Stack(
      children: [
        BaseDialog(
          title: _esAlta ? 'Registrar cliente' : 'Editar cliente',
          icon: Icon(_esAlta ? Icons.person_add_rounded : Icons.person_rounded),
          actionText: 'Guardar',
          // No se cierra solo: con un dato repetido se queda abierto para
          // corregirlo.
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
                    value: _nombres,
                    onChanged: (valor) => _cambiar(() => _nombres = valor),
                    autofocus: true,
                    label: 'Nombre(s)',
                    hint: 'Juan',
                    icon: Icons.badge_rounded,
                    errorText: _errores[CampoCliente.nombres],
                  ),
                  FormTextField(
                    value: _apellidos,
                    onChanged: (valor) => _cambiar(() => _apellidos = valor),
                    label: 'Apellido(s)',
                    hint: 'Pérez López',
                    icon: Icons.badge_outlined,
                    errorText: _errores[CampoCliente.apellidos],
                  ),
                  FormTextField(
                    value: _telefono,
                    onChanged: (valor) => _cambiar(() => _telefono = valor),
                    label: 'Teléfono',
                    hint: '$_digitosTelefono dígitos',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_digitosTelefono),
                    ],
                    errorText: _errores[CampoCliente.telefono],
                  ),
                  FormTextField(
                    value: _correo,
                    onChanged: (valor) => _cambiar(() => _correo = valor),
                    label: 'Correo electrónico (opcional)',
                    hint: 'cliente@correo.com',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _errores[CampoCliente.correo],
                    onSubmitted: (_) => _guardar(),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Mientras se escribe, el formulario no acepta nada: un segundo toque
        // en guardar daría de alta al cliente dos veces.
        if (cargando) const AbsorbPointer(child: BlockProgress()),
      ],
    );
  }

  /// Aplica un cambio y retira la marca de un campo en cuanto queda bien.
  ///
  /// Sólo se revisan los campos ya marcados: nadie quiere ver "el correo no es
  /// válido" tras teclear la primera letra.
  void _cambiar(VoidCallback cambio) {
    setState(() {
      cambio();

      if (_errores.isEmpty) return;

      final vigentes = _validar();
      _errores = {for (final campo in _errores.keys) campo: ?vigentes[campo]};
    });
  }

  Map<CampoCliente, String> _validar() => validarCliente(
    nombres: _nombres,
    apellidos: _apellidos,
    telefono: _telefono,
    correo: _correo,
  );

  Future<void> _guardar() async {
    final errores = _validar();

    if (errores.isNotEmpty) {
      setState(() => _errores = errores);
      return;
    }

    final notifier = ref.read(clientesViewModelProvider.notifier);

    // Partiendo del cliente que se edita se conservan su id y sus fechas;
    // en un alta, de uno en blanco.
    final guardado = await notifier.guardar(
      (widget.cliente ?? const ClienteData()).copyWith(
        nombres: _nombres,
        apellidos: _apellidos,
        telefono: _telefono,
        correo: _correo,
      ),
    );

    if (!mounted) return;

    if (guardado) {
      Navigator.of(context).pop(true);
      return;
    }

    await context.showErrorDialog(
      ref.read(clientesViewModelProvider).mensajeError,
    );
  }
}
