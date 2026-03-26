import 'package:get_it/get_it.dart';
import 'package:kumarket/data/services/cart_service.dart';
import 'package:kumarket/data/services/permission_service.dart';
import 'package:kumarket/data/services/products_service.dart';
import 'package:kumarket/data/services/storage_service.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  if (!sl.isRegistered<StorageService>()) {
    sl.registerLazySingleton<StorageService>(() => StorageService());
  }
  if (!sl.isRegistered<PermissionService>()) {
    sl.registerLazySingleton<PermissionService>(() => PermissionService());
  }
  if (!sl.isRegistered<ProductsService>()) {
    sl.registerLazySingleton<ProductsService>(() => ProductsService());
  }
  if (!sl.isRegistered<CartService>()) {
    sl.registerLazySingleton<CartService>(
      () => CartService(sl<ProductsService>()),
    );
  }
}
