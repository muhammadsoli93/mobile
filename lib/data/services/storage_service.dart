import 'package:get_storage/get_storage.dart';

final class StorageService {
  final _storage = GetStorage();

  Future<void> clear() => _storage.erase();

  //isIntroShown
  bool get getIsIntroScreen => _storage.read('isIntroScreen') ?? false;
  set setIsIntroScreen(bool value) => _storage.write('isIntroScreen', value);
}
