import 'package:gestion_lavanderia/data/local/app_database.dart';
import 'package:gestion_lavanderia/data/local/categorias/categoria_servicio_dao.dart';
import 'package:gestion_lavanderia/datasource/local/categorias_local_datasource.dart';
import 'package:gestion_lavanderia/inject/module_inject.dart';

/// Todo lo que necesita el módulo de categorías de ropa: su DAO y su
/// datasource.
///
/// El datasource también usa el DAO de precios —desactivar una categoría
/// arrastra a sus conceptos en una sola operación—, y ese lo registra
/// `precios_module`. No hace falta hacer nada al respecto: get_it resuelve por
/// tipo sin importar qué módulo lo registró, y al ser todo perezoso el orden en
/// que se registran los módulos tampoco importa.
class CategoriasModule extends ModuleInject {
  const CategoriasModule();

  @override
  Future<void> injectAll() async {
    instance
      ..registerLazySingleton<CategoriaServicioDao>(
        () => instance<AppDatabase>().categoriaServicioDao,
      )
      ..registerLazySingleton<CategoriasLocalDatasource>(
        () => CategoriasLocalDatasource(
          instance(),
          instance(),
          instance(),
          instance(),
        ),
      );
  }
}
