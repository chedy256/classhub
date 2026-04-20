import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissionService {
  /// check the storage permission
  static Future<bool> hasPermission() async {
    // iOS and desktop don't need explicit storage permission
    if (!Platform.isAndroid) return true;

    final status = await Permission.manageExternalStorage.status;
    return status.isGranted;
  }

  /// ask for storage permission
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.manageExternalStorage.request();

    if (status.isPermanentlyDenied) await openAppSettings();

    return status.isGranted;
  }
}