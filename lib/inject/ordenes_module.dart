import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/ordenes/item_servicio_orden_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_history_dao.dart';
import 'package:gestion_lavanderia/data/local/ordenes/orden_servicio_dao.dart';
import 'package:gestion_lavanderia/datasource/local/ordenes_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';
import 'package:gestion_lavanderia/services/ticket/salida_ticket.dart';
import 'package:gestion_lavanderia/services/ticket/ticket_pdf.dart';

/// Todo lo que necesita el módulo de órdenes de servicio.
///
/// Son tres DAO porque una orden son tres tablas: la orden, la ropa que trae y
/// el historial de movimientos. Los tres se registran aquí, con la función a la
/// que pertenecen.
///
/// El datasource usa además el DAO de clientes —toda orden muestra a su
/// cliente—, que registra `clientes_module` y se resuelve por tipo.
///
/// Y el ticket: lo genera [TicketPdf], y lo que hace con él sale de la
/// aplicación —se rasteriza con un motor nativo, se guarda con el diálogo del
/// sistema, se envía por internet—, así que cada salida es un servicio
/// registrado que una prueba cambia por uno falso.
class OrdenesModule extends ModuleInject {
  const OrdenesModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<OrdenServicioDao>(
        () => instance<AppDatabase>().ordenServicioDao,
      )
      ..registerLazySingleton<OrdenHistoryDao>(
        () => instance<AppDatabase>().ordenHistoryDao,
      )
      ..registerLazySingleton<ItemServicioOrdenDao>(
        () => instance<AppDatabase>().itemServicioOrdenDao,
      )
      ..registerLazySingleton<OrdenesLocalDatasource>(
        () => OrdenesLocalDatasource(
          instance(),
          instance(),
          instance(),
          instance(),
          instance(),
          instance(),
        ),
      )
      ..registerLazySingleton<TicketPdf>(TicketPdf.new)
      ..registerLazySingleton<VistaPreviaPdf>(VistaPreviaPdf.new)
      ..registerLazySingleton<GuardadoPdf>(GuardadoPdf.new)
      ..registerLazySingleton<EnvioCorreo>(EnvioCorreo.new);
  }
}
