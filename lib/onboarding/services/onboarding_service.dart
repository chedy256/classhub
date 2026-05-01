import 'dart:io';
import 'package:file_picker/file_picker.dart';

class OnboardingService {
  static Future<String?> pickFolder() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Select a folder for ClassHub',
    );
  }

  static Future<bool> validatePath(String path) async {
    if (path.isEmpty) return false;
    return Directory(path).exists();
  }
}
