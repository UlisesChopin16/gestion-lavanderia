import 'package:flutter/material.dart';
import 'package:gestion_lavanderia/models/data/ordenes/cobro_en_efectivo.dart';
import 'package:gestion_lavanderia/types/metodo_pago_type.dart';
import 'package:gestion_lavanderia/ui/shared/widgets/widgets.dart';

/// El cobro de la orden, al pie de la ropa que lo produce: lo que suma, lo
/// que queda a deber, con qué se paga, cuánto se adelanta y, si es en
/// efectivo, con cuánto paga el cliente.
///
/// Todo va en la misma tarjeta porque se decide junto —se mira el total, se
/// dice cómo paga y se escribe lo que deja—, y las cifras de arriba cambian
/// con lo que se escriba abajo: separarlas obligaba a mirar a dos sitios para
/// entender una sola cuenta.
///
/// Va apretada a propósito: cada línea que se gasta aquí es una prenda menos
/// a la vista en la lista de arriba, que es la única parte de la columna que
/// crece con la orden. Por eso es una rejilla de dos columnas a la que cada
/// fila se ajusta, con los campos en su versión densa:
///
/// ```text
/// Total          318.00 │ Queda a deber    218.00
/// [Método de pago     ▾]   [Adelanto] (Nada)(Todo)
/// [Recibe             ]   [Cambio          182.00]
/// ```
///
/// La última fila sólo aparece con un adelanto en efectivo: sin billete no
/// hay cambio que sacar, y la orden que nace sin adelanto —la mayoría— no
/// paga ese renglón de alto.
class CobroOrden extends StatelessWidget {
  const CobroOrden({
    super.key,
    required this.total,
    required this.abono,
    required this.recibido,
    required this.metodoPago,
    required this.onAbono,
    required this.onRecibido,
    required this.onMetodoPago,
  });

  final double total;

  /// Lo que el cliente deja al dejar la ropa.
  final double abono;

  /// Con cuánto paga ese adelanto cuando es en efectivo.
  final double recibido;

  final MetodoPagoType metodoPago;
  final ValueChanged<double> onAbono;
  final ValueChanged<double> onRecibido;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  /// Lo que los controles necesitan para ir dos por renglón. Por debajo de eso
  /// el método de pago se queda sin sitio para decir cuál es, así que cada
  /// grupo se va a un renglón propio.
  static const double _anchoDeDosColumnas = 408;

  /// El aire entre las dos columnas de la tarjeta, y lo que mide el separador
  /// que va en medio de la fila de cifras. Las demás filas dejan el mismo
  /// hueco sin pintar nada: así todas empiezan y acaban en el mismo sitio.
  static const double _aire = 12;
  static const double _separador = 1;

  /// Cómo se parte la tarjeta. No a medias: a la derecha va el adelanto con
  /// sus dos atajos, y el corte es el mismo en todas las filas para que las
  /// columnas se lean a plomo. De paso, «Queda a deber» es la etiqueta larga
  /// de arriba y agradece el sitio.
  static const int _izquierda = 45;
  static const int _derecha = 55;

  /// El alto de los controles. Van iguales porque están en fila: uno más alto
  /// que los otros se lee como un error antes que como un detalle.
  static const double _altoControl = 44;

  @override
  Widget build(BuildContext context) {
    final efectivo = CobroEnEfectivo(
      metodoPago: metodoPago,
      abono: abono,
      recibido: recibido,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          _Cifras(total: total, resta: total - abono),
          const Divider(),
          _Controles(
            total: total,
            abono: abono,
            metodoPago: metodoPago,
            efectivo: efectivo,
            onAbono: onAbono,
            onRecibido: onRecibido,
            onMetodoPago: onMetodoPago,
          ),
        ],
      ),
    );
  }
}

/// Lo que suma la orden y lo que falta por pagar, uno al lado del otro.
class _Cifras extends StatelessWidget {
  const _Cifras({required this.total, required this.resta});

  final double total;

  /// Lo que queda a deber. En cero o menos, la orden está pagada.
  final double resta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      spacing: CobroOrden._aire,
      children: [
        Expanded(
          flex: CobroOrden._izquierda,
          child: _Cifra(
            etiqueta: 'Total',
            importe: total,
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
            etiqueta: resta > 0 ? 'Queda a deber' : 'Pagada',
            importe: resta,
            estilo: theme.textTheme.titleLarge?.copyWith(
              color: resta > 0 ? scheme.error : scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Con qué paga, cuánto deja y, en efectivo, con cuánto paga.
class _Controles extends StatelessWidget {
  const _Controles({
    required this.total,
    required this.abono,
    required this.metodoPago,
    required this.efectivo,
    required this.onAbono,
    required this.onRecibido,
    required this.onMetodoPago,
  });

  final double total;
  final double abono;
  final MetodoPagoType metodoPago;
  final CobroEnEfectivo efectivo;
  final ValueChanged<double> onAbono;
  final ValueChanged<double> onRecibido;
  final ValueChanged<MetodoPagoType> onMetodoPago;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          final metodo = _MetodoPago(
            metodoPago: metodoPago,
            onMetodoPago: onMetodoPago,
          );
          final adelanto = _Adelanto(
            total: total,
            abono: abono,
            onAbono: onAbono,
          );
          final recibe = CampoImporte(
            etiqueta: 'Recibe',
            valor: efectivo.recibido,
            onCambio: onRecibido,
          );
          final cambio = _Cambio(efectivo: efectivo);

          if (constraints.maxWidth < CobroOrden._anchoDeDosColumnas) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                metodo,
                adelanto,
                if (efectivo.aplica)
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: recibe),
                      Expanded(child: cambio),
                    ],
                  ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              _Fila(izquierda: metodo, derecha: adelanto),
              if (efectivo.aplica) _Fila(izquierda: recibe, derecha: cambio),
            ],
          );
        },
      ),
    );
  }
}

/// Una fila de la rejilla de la tarjeta, con el mismo corte que las cifras.
///
/// El hueco del separador se respeta aunque aquí no se pinte: es lo que hace
/// que todas las filas empiecen y acaben en la misma columna.
class _Fila extends StatelessWidget {
  const _Fila({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: CobroOrden._aire,
      children: [
        Expanded(flex: CobroOrden._izquierda, child: izquierda),
        const SizedBox(width: CobroOrden._separador),
        Expanded(flex: CobroOrden._derecha, child: derecha),
      ],
    );
  }
}

/// Cuánto deja el cliente al dejar la ropa, con sus dos atajos.
///
/// Los atajos cubren lo que pasa casi siempre: o no deja nada, o paga
/// completo. Cualquier otra cantidad se escribe.
class _Adelanto extends StatelessWidget {
  const _Adelanto({
    required this.total,
    required this.abono,
    required this.onAbono,
  });

  final double total;
  final double abono;
  final ValueChanged<double> onAbono;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: CampoImporte(
            etiqueta: 'Adelanto',
            valor: abono,
            onCambio: onAbono,
          ),
        ),
        _Atajo(texto: 'Nada', activo: abono == 0, onPressed: () => onAbono(0)),
        _Atajo(
          texto: 'Todo',
          activo: abono == total && total > 0,
          onPressed: () => onAbono(total),
        ),
      ],
    );
  }
}

/// Lo que se le devuelve al cliente, o lo que le falta al billete.
///
/// Es una cifra y no un campo, pero mide y se redondea como los campos de la
/// fila: va al lado de «Recibe» y tiene que leerse como su pareja.
class _Cambio extends StatelessWidget {
  const _Cambio({required this.efectivo});

  final CobroEnEfectivo efectivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Sin nada escrito se da por pagado justo: no hay cambio, y no se pinta
    // como si lo hubiera.
    final (etiqueta, importe, fondo, texto) = switch (efectivo) {
      CobroEnEfectivo(insuficiente: true) => (
        'Faltan',
        -efectivo.cambio,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      CobroEnEfectivo(recibido: 0) => (
        'Sin cambio',
        0.0,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _ => (
        'Cambio',
        efectivo.cambio,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };

    return Container(
      height: CobroOrden._altoControl,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 8,
        children: [
          Text(
            etiqueta,
            style: theme.textTheme.labelLarge?.copyWith(color: texto),
          ),
          Text(
            importe.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(color: texto),
          ),
        ],
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
