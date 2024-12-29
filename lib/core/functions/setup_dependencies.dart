import 'package:get_it/get_it.dart';
import 'package:kumarket/data/services/permission_service.dart';
import 'package:kumarket/data/services/storage_service.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  //storageSerice
  sl.registerLazySingleton(
    () => StorageService(),
  );
  //permissionService
  sl.registerLazySingleton(
    () => PermissionService(),
  );
}
