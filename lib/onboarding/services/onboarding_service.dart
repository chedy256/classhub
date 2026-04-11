import 'dart:io';
import 'package:flutter/foundation.dart'; //check if the app works on web
import 'package:file_picker/file_picker.dart'; //allows user to pick folder from device
import 'package:classhub/core/services/classhub_path_service.dart'; //service to load/save path inSharedPreferences
import 'package:classhub/core/services/storage_permission_service.dart'; //requests storage permission from user

class OnboardingService {
  static Future<String?> loadSavedPath() async {
    /// Returns the previously saved path, or null if none is stored.

    final path = await ClasshubPathService.getPath();
    //loads saved path from local storage
    final hasCustomPath = await ClasshubPathService.hasCustomPath();
    //chechks if the path is chosen
    return hasCustomPath ? path : null;
    //return the path,null if not
  }

  /// Requests storage permission and opens the folder picker.
  static Future<Map<String, dynamic>> pickFolder() async {
    //opens folder picker and returns the selected path
    if (kIsWeb) {
      return {'hasPermission': true, 'path': '/web/simulated/folder'};
    }
    //returns a simulated path for   web

    final hasPermission = await StoragePermissionService.requestPermission();
    //checks if user has chosen a path for storage
    if (!hasPermission) {
      return {'hasPermission': false, 'path': null};
      //false if permission is denied
    }

    final String? selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select a folder for ClassHub',
    );

    if (selectedPath != null) {
      await ClasshubPathService.savePath(
        selectedPath,
      ); //waits for user to pick a folder
    }

    return {
      'hasPermission': true,
      'path': selectedPath,
    }; //rue if permission is granted
  }

  /// Returns true only if the directory actually exists.
  static Future<bool> validatePath(String path) async {
    if (path.isEmpty) return false;
    return Directory(path).exists();
  }
}
