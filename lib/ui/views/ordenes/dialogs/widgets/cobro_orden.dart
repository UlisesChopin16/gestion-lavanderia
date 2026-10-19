import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';

/// El cobro de la orden, al pie de la ropa que lo produce: lo que suma, lo
/// que queda a deber, con qué se paga y cuánto se adelanta.
///
/// Las cuatro cosas van en la misma tarjeta porque se deciden juntas —se mira
/// el total, se dice cómo paga y se escribe lo que deja—, y la resta cambia
/// con lo que se escriba al lado: separarlas obligaba a mirar a dos sitios
/// para entender una sola cuenta.
///
/// Va apretada a propósito: cada línea que se gasta aquí es una prenda menos
/// a la vista en la lista de arriba, que es la única parte de la columna que
/// crece con la orden. Por eso las dos cifras comparten renglón, los tres
/// controles comparten el siguiente, y los campos van en su versión densa.
///
/// Los dos atajos del adelanto cubren lo que pasa casi siempre: o no deja
/// nada, o paga completo. Cualquier otra cantidad se escribe.
class CobroOrden extends StatefulWidget {
  const CobroOrden({
    super.key,
    required this.total,
    required this.abono,
    required this.metodoPago,
    required this.onAbono,
    required this.onMetodoPago,
  });

  final double total;

  /// Lo que el cliente deja al dejar la ropa.
  final double abono;

  final MetodoPagoType metodoPago;
  final ValueChanged<double> onAbono;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  /// Lo que los tres controles necesitan para caber en un renglón. Por debajo
  /// de eso el método de pago se queda sin sitio para decir cuál es, así que
  /// se va a un renglón propio.
  static const double _anchoDeUnRenglon = 408;

  /// El aire entre las dos mitades de la tarjeta, y lo que mide el separador
  /// que va en medio de la primera fila. La segunda deja el mismo hueco sin
  /// pintar nada: así las dos columnas empiezan y acaban en el mismo sitio.
  static const double _aire = 12;
  static const double _separador = 1;

  /// Cómo se parte la tarjeta. No a medias: a la izquierda va un control y a
  /// la derecha tres, y el corte es el mismo en las dos filas para que las
  /// columnas se lean a plomo. De paso, «Queda a deber» es la etiqueta larga
  /// de arriba y agradece el sitio.
  static const int _izquierda = 45;
  static const int _derecha = 55;

  /// El alto de los tres controles. Van iguales porque están en fila: uno más
  /// alto que los otros se lee como un error antes que como un detalle.
  static const double _altoControl = 44;

  @override
  State<CobroOrden> createState() => _CobroOrdenState();
}

class _CobroOrdenState extends State<CobroOrden> {
  late final TextEditingController _controller = TextEditingController(
    text: _texto,
  );

  String get _texto => widget.abono.toStringAsFixed(2);

  double get _resta => widget.total - widget.abono;

  @override
  void didUpdateWidget(CobroOrden oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se compara el número y no el texto: "50" y "50.00" son el mismo abono,
    // y reescribir el campo a media captura movería el cursor al final. Lo
    // que sí se repone es un cambio que viene de fuera —un atajo, o el
    // recorte al quitar ropa—, porque entonces el número ya no es el escrito.
    final escrito = double.tryParse(_controller.text);
    if (escrito != widget.abono) _controller.text = _texto;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [_cifras(theme), _controles(theme)],
      ),
    );
  }

  /// Lo que suma la orden y lo que falta por pagar, uno al lado del otro.
  Widget _cifras(ThemeData theme) {
    final scheme = theme.colorScheme;

    return Row(
      spacing: CobroOrden._aire,
      children: [
        Expanded(
          flex: CobroOrden._izquierda,
          child: _Cifra(
            etiqueta: 'Total',
            importe: widget.total,
            estilo: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 24,
          child: VerticalDivider(
            width: CobroOrden._separador,
            color: scheme.outlineVariant,
          ),
        ),
        Expanded(
          flex: CobroOrden._derecha,
          child: _Cifra(
            // La etiqueta dice el estado y el color lo repite: una orden que
            // queda a deber se reconoce sin leer la cifra.
            etiqueta: _resta > 0 ? 'Queda a deber' : 'Pagada',
            importe: _resta,
            estilo: theme.textTheme.titleLarge?.copyWith(
              color: _resta > 0 ? scheme.error : scheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Con qué paga y cuánto deja.
  Widget _controles(ThemeData theme) {
    final metodo = _MetodoPago(
      metodoPago: widget.metodoPago,
      onMetodoPago: widget.onMetodoPago,
    );

    // El icono de delante no es un adorno: la etiqueta de un campo con marco
    // se dibuja en un hueco de la línea de arriba, y sin icono empieza a diez
    // píxeles del borde y se lleva casi toda esa línea. El campo se queda
    // abierto por arriba y se lee más bajo que el desplegable de al lado, que
    // sí tiene icono. Con él, los dos marcos empiezan en el mismo sitio.
    //
    // Va acotado a mano porque Material le reserva a un icono de campo los
    // cuarenta y ocho píxeles del dedo, y aquí eso es ancho que le falta al
    // importe.
    final adelanto = TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Adelanto',
        prefixIcon: Icon(Icons.payments_rounded, size: 18),
        prefixIconConstraints: BoxConstraints(minWidth: 34),
      ),
      onChanged: (texto) => widget.onAbono(double.tryParse(texto) ?? 0),
    );

    final atajos = [
      _Atajo(
        texto: 'Nada',
        activo: widget.abono == 0,
        onPressed: () => widget.onAbono(0),
      ),
      _Atajo(
        texto: 'Todo',
        activo: widget.abono == widget.total && widget.total > 0,
        onPressed: () => widget.onAbono(widget.total),
      ),
    ];

    // Los campos, en su versión densa. Se cambia el tema en lugar de cada
    // control porque el desplegable no recibe su decoración por parámetro: la
    // lee de aquí. Lo único que cambia son los rellenos y la densidad; los
    // bordes y los colores siguen siendo los de la aplicación.
    //
    // La densidad vuelve a la normal a propósito. En escritorio Material la
    // pone en `-2`, que son ocho píxeles menos de alto, y no todos los
    // controles la aplican: el campo de texto y los botones encogían a
    // treinta y seis mientras el desplegable se quedaba en cuarenta y cuatro,
    // y la fila salía descuadrada. Aquí el alto lo fija esta tarjeta, que para
    // eso los pide todos iguales.
    //
    // El tema de los botones de icono es por la flecha del desplegable: es un
    // `IconButton`, y con los cuarenta y ocho píxeles que Material le reserva
    // para el dedo el desplegable salía un dedo más alto que el campo de al
    // lado. Aquí dentro no hay más botones de icono que ésa.
    return Theme(
      data: theme.copyWith(
        visualDensity: VisualDensity.standard,
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 10,
          ),
          // El alto, a mano: el icono que el desplegable lleva delante pide
          // los cuarenta y ocho de Material por su cuenta y dejaba un control
          // más alto que los otros dos.
          constraints: const BoxConstraints.tightFor(
            height: CobroOrden._altoControl,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size.square(CobroOrden._altoControl - 12),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < CobroOrden._anchoDeUnRenglon) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                metodo,
                Row(
                  spacing: 8,
                  children: [Expanded(child: adelanto), ...atajos],
                ),
              ],
            );
          }

          // La misma rejilla que las cifras de arriba: el método de pago
          // debajo del total, y lo que se adelanta debajo de lo que queda a
          // deber, que es la cifra que mueve. Las dos filas empiezan y acaban
          // en la misma columna, y el hueco del separador se respeta aunque
          // aquí no se pinte.
          return Row(
            spacing: CobroOrden._aire,
            children: [
              Expanded(flex: CobroOrden._izquierda, child: metodo),
              const SizedBox(width: CobroOrden._separador),
              Expanded(
                flex: CobroOrden._derecha,
                child: Row(
                  spacing: 8,
                  children: [Expanded(child: adelanto), ...atajos],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Con qué paga el cliente lo que deja ahora.
class _MetodoPago extends StatelessWidget {
  const _MetodoPago({required this.metodoPago, required this.onMetodoPago});

  final MetodoPagoType metodoPago;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuBase<MetodoPagoType>(
      label: 'Método de pago',
      value: metodoPago,
      leadingIcon: Icon(metodoPago.icon),
      items: [
        for (final metodo in MetodoPagoType.values)
          DropdownMenuEntry<MetodoPagoType>(
            value: metodo,
            label: metodo.value,
            leadingIcon: Icon(metodo.icon),
          ),
      ],
      onChanged: (metodo) => onMetodoPago(metodo ?? metodoPago),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.importe,
    required this.estilo,
  });

  final String etiqueta;
  final double importe;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8,
      children: [
        Flexible(
          child: Text(
            etiqueta,
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(importe.toStringAsFixed(2), style: estilo),
      ],
    );
  }
}

/// Un atajo del adelanto, marcado cuando el importe ya es ese.
///
/// Del alto del campo que tiene al lado y no del de un botón suelto: en una
/// barra de cobro de un solo renglón, el relleno que Material le da a un
/// botón es justo el ancho que le falta al método de pago.
///
/// Los dos miden lo mismo aunque «Nada» y «Todo» no ocupen igual: dos botones
/// pegados y de anchos distintos por tres píxeles se leen como un descuadre,
/// no como dos palabras de largo distinto.
class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.texto,
    required this.activo,
    required this.onPressed,
  });

  final String texto;
  final bool activo;
  final VoidCallback onPressed;

  static const EdgeInsets _relleno = EdgeInsets.symmetric(horizontal: 10);
  static const Size _minimo = Size(62, CobroOrden._altoControl);

  @override
  Widget build(BuildContext context) {
    if (activo) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: _relleno,
          minimumSize: _minimo,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(texto),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: _relleno,
        minimumSize: _minimo,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(texto),
    );
  }
}
