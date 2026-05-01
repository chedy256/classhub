import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:classhub/core/services/classhub_storage_service.dart';
import 'package:classhub/core/services/storage_permission_service.dart';

class OnboardingService {
  /// Returns the previously saved path, or null if none is stored.
  static Future<String?> loadSavedPath() async {
    final hasCustomPath = await ClasshubStorageService.hasCustomPath();
    if (!hasCustomPath) return null;
    return ClasshubStorageService.getPath();
  }

  /// Requests storage permission and opens the folder picker.
  static Future<Map<String, dynamic>> pickFolder() async {
    final hasPermission = await StoragePermissionService.requestPermission();
    if (!hasPermission) {
      return {'hasPermission': false, 'path': null};
    }

    final String? selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select a folder for ClassHub',
    );

    if (selectedPath != null) {
      await ClasshubStorageService.savePath(selectedPath);
    }

    return {'hasPermission': true, 'path': selectedPath};
  }

  /// Returns true only if the directory actually exists.
  static Future<bool> validatePath(String path) async {
    if (path.isEmpty) return false;
    return Directory(path).exists();
  }
}
