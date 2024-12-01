import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphic/graphic.dart';
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

  group("Implementation control", () {
    testWidgets("Start app, Fl_Charts is the selected implementation",
        (WidgetTester tester) async {
      // Given nothing
      // When I launch the plotting application
      await startDemoApp(tester);

      // Then Fl_Charts is the selected implementation
      expect(
          find.descendant(
              of: find.byType(DropdownMenu<String>),
              matching: find.text("Fl_Charts")),
          findsNWidgets(2));

      // ... and flCharts widgets are being displayed
      expect(find.byType(LineChart), findsAtLeast(1));

      // ... and NO Graphic widgets are being displayed
      expect(find.byType(Chart), findsNothing);
    });

    testWidgets("Select Graphic, Plot Widgets change to Graphic implementation",
        (WidgetTester tester) async {
      // Given the application is running with Plot Implementation set to Fl_Charts
      await startDemoApp(tester);

      // When I select Graphic from the Plot Implementation menu
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Graphic").first);
      await tester.pumpAndSettle();

      // Then Graphic is the selected implementation
      expect(
          find.descendant(
              of: find.byType(DropdownMenu<String>),
              matching: find.text("Graphic")),
          findsNWidgets(2));

      // ... and flCharts widgets are NOT being displayed
      expect(find.byType(LineChart), findsNothing);

      // ... and Graphic widgets are being displayed
      expect(find.byType(Chart), findsWidgets);
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
