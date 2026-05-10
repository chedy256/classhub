import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classhub/main.dart';

void main() {
  testWidgets('ClasshubApp builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ClasshubApp(
        isSetupComplete: false,
        rootPath: '/test/path',
        initialThemeMode: ThemeMode.system,
      ),
    );
    expect(find.text('ClassHub'), findsOneWidget);
  });
}
