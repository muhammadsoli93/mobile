import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:kumarket/aplication.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 150 * 1024 * 1024;
  await GetStorage.init();
  runApp(const Application());
}
