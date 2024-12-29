import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:kumarket/aplication.dart';
import 'package:kumarket/core/functions/setup_dependencies.dart';
// import 'package:kumarket/data/services/storage_service.dart';

Future<void> main()async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await setupDependencies();
  // sl<StorageService>().clear();
  runApp(const Application());
}
