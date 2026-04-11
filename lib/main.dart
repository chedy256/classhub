import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'package:classhub/core/services/storage_permission_service.dart';
import 'package:classhub/core/services/classhub_path_service.dart';
import 'package:classhub/onboarding/screens/onboarding_screen.dart';
import 'package:classhub/file_explorer/screens/file_explorer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String savedPath = await ClasshubPathService.getPath();
  final bool hasPermission = await StoragePermissionService.hasPermission();
  final bool pathExists = await Directory(savedPath).exists();

  runApp(ClasshubApp(isSetupComplete: hasPermission && pathExists));
}

class ClasshubApp extends StatelessWidget {
  final bool isSetupComplete;
  const ClasshubApp({super.key, required this.isSetupComplete});

  // Fallback palette for devices without dynamic color (iOS, older Android)
  static const _fallbackSeed = Colors.indigo;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme =
            lightDynamic?.harmonized() ??
            ColorScheme.fromSeed(seedColor: _fallbackSeed);
        final darkScheme =
            darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Classhub',
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: isSetupComplete ? FileExplorerScreen() : OnboardingScreen(),
          // home: HomeScreen(),
        );
      },
    );
  }
}
