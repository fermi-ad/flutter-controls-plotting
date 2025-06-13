import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void assertEmptyPlot(WidgetTester tester, {required bool isVisible}) {
  final plotFinder = find.byType(PlotWidget);
  expect(plotFinder, isVisible ? findsOneWidget : findsNothing);

  if (isVisible) {
    final PlotState plotState = tester.state(plotFinder);
    expect(plotState.channelData.length, 0);
  }
}

void assertColorOfPlot(WidgetTester tester, {required Color expectedColor}) {
  final PlotState plotState = tester.state(find.byType(PlotWidget));

  expect(plotState.channelColors.first, expectedColor);
}

void assertPlotXAxisTitle(WidgetTester tester, {required String title}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  expect(plotState.xAxisTitle, title);
}

void assertPlotYAxisTitles(WidgetTester tester,
    {required List<String> titles, required List<String> units}) {
  expect(titles.length, units.length);

  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  expect(plotState.channelNames.length, titles.length);
  expect(plotState.channelUnits.length, units.length);

  for (int i = 0; i != titles.length; i++) {
    expect(plotState.channelNames[i], titles[i]);
    expect(plotState.channelUnits[i], units[i]);
  }
}

void assertDifferentColorsYAxisLabels(WidgetTester tester,
    {required int expectedLabelCount, String title = 'PLOT TEST'}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;
  var yLabels = plotState.channelNames;
  expect(yLabels.length, expectedLabelCount);

  var uniqueColors = [];

  for (final color in plotState.channelColors) {
    // Make sure some color was defined.
    expect(color, isNotNull);
    // Make sure color is unique
    expect(uniqueColors.contains(color), isFalse);
    uniqueColors.add(color);
  }
}

void assertPlotXAxisLimits(WidgetTester tester,
    {required double min, required double max}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;
  expect(plotState.minX, closeTo(min, 0.01));
  expect(plotState.maxX, closeTo(max, 0.01));
}

void assertConfigTimeLimits(WidgetTester tester,
    {required String timeMin, required String timeMax}) {
  final timeMinTextField = find.byKey(const ValueKey('TimeMinTextField'));
  final timeMaxTextField = find.byKey(const ValueKey('TimeMaxTextField'));

  final timeMinText =
      tester.widget<TextFormField>(timeMinTextField).controller?.text;
  final timeMaxText =
      tester.widget<TextFormField>(timeMaxTextField).controller?.text;

  expect(timeMinText, equals(timeMin));
  expect(timeMaxText, equals(timeMax));
}

void assertPlotYAxisLimits(WidgetTester tester,
    {required double min, required double max}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  expect(plotState.minY, closeTo(min, 0.01));
  expect(plotState.maxY, closeTo(max, 0.01));
}

void assertPlotContainsHorizontalLine(WidgetTester tester,
    {required int numberOfPoints,
    required double atY,
    required String channelName}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(atY, 0.01));
  }
}

void assertPlotContainsRamp(WidgetTester tester,
    {required int numberOfPoints,
    required double startingAtY,
    required String channelName}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(startingAtY + i, 0.01));
  }
}

void assertPlotContainsParabola(WidgetTester tester,
    {required int numberOfPoints,
    required double startingAtX,
    required String channelName}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(pow(x, 2), 0.01));
  }
}

void assertPlotContainsSineWave(WidgetTester tester,
    {required int numberOfPoints,
    required int startingAtX,
    required String channelName}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(sin(x * 6.28 / 500), 0.01));
  }
}

Future<void> assertPlotPointsDifferent(WidgetTester tester,
    {required String channelName}) async {
  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  var changed = false;

  await tester.pumpAndSettle();

  final plotPointsAfter = _getPlotPoints(tester, channelName: channelName);

  expect(plotPoints.length, plotPointsAfter.length);

  for (int i = 0; i < plotPoints.length; i++) {
    var pointsBefore = plotPoints[i];
    var pointsAfter = plotPointsAfter[i];

    if (pointsBefore.x != pointsAfter.x) {
      changed = true;
      break;
    }

    if (pointsBefore.y != pointsAfter.y) {
      changed = true;
      break;
    }
  }

  expect(changed, true);
}

void assertPlotContainsNormalDistribution(WidgetTester tester,
    {required int numberOfPoints,
    required int centeredAtX,
    required String channelName}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(
        plotPoints[i].y,
        closeTo(
            (pow(500, 2) / 4) *
                pow(e, -(pow(i - 250, 2) / (2 * pow(50, 2)))).toDouble() /
                (50 * sqrt(2 * pi)),
            0.01));
  }
}

void assertPlotContainsNPoints(WidgetTester tester, dynamic numberOfPoints,
    {required String channelName, int segment = 0}) {
  final plotPoints =
      _getPlotPoints(tester, channelName: channelName, segment: segment);

  expect(plotPoints.length, numberOfPoints);
}

Future<void> assertPlotIsPaused(WidgetTester tester) async {
  final beforePlotWidget =
      find.byType(PlotWidget).evaluate().first.widget as PlotWidget;
  final beforeXMax = beforePlotWidget.plotData.maxX!;

  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }

  final afterPlotWidget =
      find.byType(PlotWidget).evaluate().first.widget as PlotWidget;
  final afterXMax = afterPlotWidget.plotData.maxX!;

  expect(afterXMax - beforeXMax, 0);
}

void assertPlotContainsNSegments(WidgetTester tester, int numberOfSegments,
    {required String channelName}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;
  final pointSegments = plotState.points[channelName] ?? [];

  expect(pointSegments.length, numberOfSegments);
}

void assertPlotLoadingIndicator({required bool isVisible}) => expect(
    find.byType(LinearProgressIndicator),
    isVisible ? findsOneWidget : findsNothing);

List<PlotPoint> _getPlotPoints(WidgetTester tester,
    {required String channelName, int segment = 0}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  return plotState.points[channelName]?[segment] ?? [];
}
