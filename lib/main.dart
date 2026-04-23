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

  final String savedPath = await ClasshubPathService.getPath();
  final bool hasPermission = await StoragePermissionService.hasPermission();
  final bool pathExists = await Directory(savedPath).exists();

  runApp(
    ClasshubApp(
      isSetupComplete: hasPermission && pathExists,
      rootPath: savedPath,
    ),
  );
}

class ClasshubApp extends StatelessWidget {
  final bool isSetupComplete;
  final String rootPath;
  const ClasshubApp({
    super.key,
    required this.isSetupComplete,
    required this.rootPath,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Classhub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(lightDynamic, Brightness.light),
          darkTheme: AppTheme.build(darkDynamic, Brightness.dark),
          themeMode: ThemeMode.system,
          home: isSetupComplete
              ? MainScreen(rootPath: rootPath)
              : const LandingPage1(),
        );
      },
    );
  }
}