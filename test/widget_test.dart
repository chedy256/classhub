import 'package:flutter_test/flutter_test.dart';

import 'package:classhub/main.dart';

void main() {
  testWidgets('ClasshubApp builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ClasshubApp(
        isSetupComplete: false,
        rootPath: '/test/path',
      ),
    );
    expect(find.text('ClassHub'), findsOneWidget);
  });
}
