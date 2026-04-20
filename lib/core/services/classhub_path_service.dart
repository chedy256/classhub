import 'package:shared_preferences/shared_preferences.dart';

class ClasshubPathService {
  static const String _pathKey = 'classhub_root_path';

  /// Returns the saved root path, or default Android path if none set.
  static Future<String> getPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey) ?? '';
    if (path.isEmpty) return '/storage/emulated/0';
    return path;
  }

  /// Whether the user has explicitly chosen a path.
  static Future<bool> hasCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pathKey);
    return saved != null && saved.isNotEmpty;
  }

  /// Saves the user's chosen path.
  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }
}