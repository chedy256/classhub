import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClasshubStorageService {
  static const String _pathKey = 'classhub_root_path';
  static const String _themeKey = 'classhub_theme_mode';

  static Future<String> getPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey) ?? '';
    if (path.isEmpty) return null;
    return path;
  }

  static Future<bool> hasCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pathKey);
    return saved != null && saved.isNotEmpty;
  }

  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }

  static Future<int> getThemeModeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeKey);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return 0;
    }
    return index;
  }

  static Future<ThemeMode> getThemeMode() async {
    final index = await getThemeModeIndex();
    return ThemeMode.values[index];
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
}
