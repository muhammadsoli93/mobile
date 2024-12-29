import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

final class PermissionService {
  Future<bool> requestCamera() async {
    bool hasCameraPermission = false;
    final PermissionStatus status = await Permission.camera.status;
    if (status == PermissionStatus.granted) {
      hasCameraPermission = true;
    } else {
      final PermissionStatus requested = await Permission.camera.request();
      if (requested == PermissionStatus.granted) {
        hasCameraPermission = true;
      }
    }
    return Future<bool>.value(hasCameraPermission);
  }

  Future<bool> requestPhotoOrStorage() async {
    bool perm = false;
    if (Platform.isIOS) {
      perm = await _permissionPhotos();
    } else if (Platform.isAndroid) {
      final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = android.version.sdkInt;
      perm =
          sdkInt > 32 ? await _permissionPhotos() : await _permissionStorage();
    }
    return Future<bool>.value(perm);
  }

  Future<bool> _permissionPhotos() async {
    bool hasPhotosPermission = false;
    final PermissionStatus status = await Permission.photos.status;
    if (status == PermissionStatus.granted) {
      hasPhotosPermission = true;
    } else {
      final PermissionStatus requested = await Permission.photos.request();
      if (requested == PermissionStatus.granted) {
        hasPhotosPermission = true;
      }
    }
    return Future<bool>.value(hasPhotosPermission);
  }

  Future<bool> _permissionStorage() async {
    bool hasStoragePermission = false;
    final PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.granted) {
      hasStoragePermission = true;
    } else {
      final PermissionStatus requested = await Permission.storage.request();
      if (requested == PermissionStatus.granted) {
        hasStoragePermission = true;
      }
    }
    return Future<bool>.value(hasStoragePermission);
  }
}
