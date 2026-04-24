import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:classhub/core/theme/app_theme.dart';
import 'package:classhub/onboarding/screens/landing_page1.dart';
import 'package:classhub/core/services/storage_permission_service.dart';
import 'package:classhub/core/services/classhub_path_service.dart';

import 'package:classhub/file_explorer/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedPath = await ClasshubPathService.getPath();
  final savedThemeModeIndex = await ClasshubPathService.getThemeModeIndex();
  final savedThemeMode = ThemeMode.values[savedThemeModeIndex];
  final hasPermission = await StoragePermissionService.hasPermission();
  final pathExists = await Directory(savedPath).exists();

  runApp(
    ClasshubApp(
      isSetupComplete: hasPermission && pathExists,
      rootPath: savedPath,
      initialThemeMode: savedThemeMode,
    ),
  );
}

class ClasshubApp extends StatefulWidget {
  final bool isSetupComplete;
  final String rootPath;
  final ThemeMode initialThemeMode;

  const ClasshubApp({
    super.key,
    required this.isSetupComplete,
    required this.rootPath,
    required this.initialThemeMode,
  });

  @override
  State<ClasshubApp> createState() => _ClasshubAppState();
}

class _ClasshubAppState extends State<ClasshubApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    debugPrint('[Theme] initState: _themeMode=$_themeMode');
  }

  void updateTheme(ThemeMode mode) {
    debugPrint('[ClasshubApp] updateTheme called: mode=$mode');
    setState(() {
      debugPrint('[ClasshubApp] setState updating _themeMode from $_themeMode to $mode');
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ClasshubApp] build: _themeMode=$_themeMode');
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final bool isDark = _themeMode == ThemeMode.dark;
        final bool isLight = _themeMode == ThemeMode.light;
        final scheme = isDark 
            ? (darkDynamic ?? ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0), brightness: Brightness.dark))
            : (lightDynamic ?? ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0), brightness: Brightness.light));
        
        debugPrint('[ClasshubApp] isDark=$isDark, isLight=$isLight, scheme brightness=${scheme.brightness}');
        
        return MaterialApp(
          title: 'ClassHub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(lightDynamic, Brightness.light),
          darkTheme: AppTheme.build(darkDynamic, Brightness.dark),
          themeMode: _themeMode,
          home: widget.isSetupComplete
              ? MainScreen(rootPath: widget.rootPath, onThemeChanged: updateTheme)
              : const LandingPage1(),
        );
      },
    );
  }
}
