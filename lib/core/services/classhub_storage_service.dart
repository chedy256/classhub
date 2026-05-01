import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class ClasshubStorageService {
  static const String _pathKey = 'classhub_root_path';
  static const String _themeKey = 'classhub_theme_mode';

  static Future<String?> getPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }

  static String getDefaultPath() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/ClassHub';
    } else if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? '';
      return p.join(home, 'Documents', 'ClassHub');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Documents', 'ClassHub');
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'ClassHub');
    }
    return p.join(Directory.current.path, 'ClassHub');
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
