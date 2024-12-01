import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_controls_plotting/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke tests', () {
    testWidgets("Start app, title should be displayed",
        (WidgetTester tester) async {
      // Given nothing
      // When I launch the plotting application
      await startDemoApp(tester);

      // Then the app title should be displayed
      assertAppBarTitleIsVisible();
    });
  });
}

Future<void> setDesktopScreenSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> startDemoApp(WidgetTester tester) async {
  await setDesktopScreenSize(tester);
  await app.main();
  await tester.pumpAndSettle();
}

void assertAppBarTitleIsVisible() =>
    expect(find.text("Plotting Widgets Demo"), findsOneWidget);
