import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:classhub/core/theme/app_theme.dart';
import 'package:classhub/onboarding/screens/landing_page1.dart';
import 'package:classhub/core/services/storage_permission_service.dart';
import 'package:classhub/core/services/classhub_storage_service.dart';

import 'package:classhub/file_explorer/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedPath = await ClasshubStorageService.getPath();
  final savedThemeModeIndex = await ClasshubStorageService.getThemeModeIndex();
  final savedThemeMode = ThemeMode.values[savedThemeModeIndex];
  final hasPermission = await StoragePermissionService.hasPermission();
  final pathExists = savedPath != null && await Directory(savedPath).exists();

  runApp(
    ClasshubApp(
      isSetupComplete: hasPermission && pathExists,
      rootPath: savedPath ?? '',
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
  State<ClasshubApp> createState() => ClasshubAppState();
}

class ClasshubAppState extends State<ClasshubApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void updateTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'ClassHub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(lightDynamic, Brightness.light),
          darkTheme: AppTheme.build(darkDynamic, Brightness.dark),
          themeMode: _themeMode,
          home: widget.isSetupComplete
              ? MainScreen(
                  rootPath: widget.rootPath,
                  initialThemeMode: _themeMode,
                )
              : const LandingPage1(),
        );
      },
    );
  }
}
