import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/plotting_point.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
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

void assertPlotYAxisTitles(
  WidgetTester tester, {
  required List<String> titles,
  required List<String> units,
}) {
  expect(titles.length, units.length);

  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  expect(plotState.channelNames.length, titles.length);
  expect(plotState.channelUnits.length, units.length);

  for (int i = 0; i != titles.length; i++) {
    expect(plotState.channelNames[i], titles[i]);
    expect(plotState.channelUnits[i], units[i]);
  }
}

void assertDifferentColorsYAxisLabels(
  WidgetTester tester, {
  required int expectedLabelCount,
  String title = 'PLOT TEST',
}) {
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

void assertPlotXAxisLimits(
  WidgetTester tester, {
  required double min,
  required double max,
}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;
  expect(plotState.minXAxis, closeTo(min, 0.01));
  expect(plotState.maxXAxis, closeTo(max, 0.01));
}

void assertConfigTimeLimits(
  WidgetTester tester, {
  required String timeMin,
  required String timeMax,
}) {
  final timeMinTextField = find.byKey(const ValueKey('TimeMinTextField'));
  final timeMaxTextField = find.byKey(const ValueKey('TimeMaxTextField'));

  final timeMinText = tester
      .widget<TextFormField>(timeMinTextField)
      .controller
      ?.text;
  final timeMaxText = tester
      .widget<TextFormField>(timeMaxTextField)
      .controller
      ?.text;

  expect(timeMinText, equals(timeMin));
  expect(timeMaxText, equals(timeMax));
}

void assertPlotYAxisLimits(
  WidgetTester tester, {
  required String channelName,
  required double min,
  required double max,
}) {
  final plotWidget = tester.widget<PlotWidget>(find.byType(PlotWidget));
  expect(plotWidget.plotChannels[channelName]!.labelMinY, closeTo(min, 0.01));
  expect(plotWidget.plotChannels[channelName]!.labelMaxY, closeTo(max, 0.01));
}

void assertPlotYAxisLabel({
  required bool isVisible,
  required Color color,
  required String withText,
}) {
  final finder = find.descendant(
    of: find.byType(PlotYAxisLabelWidget),
    matching: findTextWithColor(withText, color),
  );

  expect(finder, isVisible ? findsAtLeastNWidgets(1) : findsNothing);
}

void assertPlotContainsHorizontalLine(
  WidgetTester tester, {
  required int numberOfPoints,
  required double atY,
  required String channelName,
}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(atY, 0.01));
  }
}

void assertPlotContainsPoints(
  WidgetTester tester, {
  required String channelName,
  required List<PlottingPoint> points,
  double xTolerance = 0,
  double yTolerance = 0,
}) {
  assertPlotContainsNPoints(tester, points.length, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);

  for (int i = 0; i != points.length; i++) {
    var plotPoint = plotPoints[i];
    var expectedPoint = points[i];

    expect(plotPoint.x, closeTo(expectedPoint.x, xTolerance));
    expect(plotPoint.y, closeTo(expectedPoint.y, yTolerance));
  }
}

void assertPlotContainsRamp(
  WidgetTester tester, {
  required int numberOfPoints,
  required double startingAtY,
  required String channelName,
}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(startingAtY + i, 0.01));
  }
}

void assertPlotContainsParabola(
  WidgetTester tester, {
  required int numberOfPoints,
  required double startingAtX,
  required String channelName,
}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(pow(x, 2), 0.01));
  }
}

void assertPlotContainsSineWave(
  WidgetTester tester, {
  required int numberOfPoints,
  required int startingAtX,
  required String channelName,
}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(sin(x * 6.28 / 500), 0.01));
  }
}

Future<void> assertPlotPointsDifferent(
  WidgetTester tester, {
  required String channelName,
  bool isNewSegment = false,
}) async {
  int segment = 0;
  if (isNewSegment) {
    var segments = _getChannelSegments(tester, channelName: channelName);
    segment = segments.length - 1;
  }

  final plotPoints = _getPlotPoints(
    tester,
    channelName: channelName,
    segment: segment,
  );
  var changed = false;

  await tester.pumpAndSettle();

  if (isNewSegment) {
    segment += 1;
  }

  final plotPointsAfter = _getPlotPoints(
    tester,
    channelName: channelName,
    segment: segment,
  );

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

void assertPlotContainsNormalDistribution(
  WidgetTester tester, {
  required int numberOfPoints,
  required int centeredAtX,
  required String channelName,
}) {
  assertPlotContainsNPoints(tester, numberOfPoints, channelName: channelName);

  final plotPoints = _getPlotPoints(tester, channelName: channelName);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(
      plotPoints[i].y,
      closeTo(
        (pow(500, 2) / 4) *
            pow(e, -(pow(i - 250, 2) / (2 * pow(50, 2)))).toDouble() /
            (50 * sqrt(2 * pi)),
        0.01,
      ),
    );
  }
}

void assertPlotContainsNPoints(
  WidgetTester tester,
  dynamic numberOfPoints, {
  required String channelName,
  int segment = 0,
}) {
  final plotPoints = _getPlotPoints(
    tester,
    channelName: channelName,
    segment: segment,
  );

  expect(plotPoints.length, numberOfPoints);
}

void assertPlotContainsStartAndEndX(
  WidgetTester tester, {
  required dynamic startX,
  required dynamic endX,
  required String channelName,
}) {
  final plotPoints = _getPlotPoints(tester, channelName: channelName);

  expect(plotPoints.first.x, startX);
  expect(plotPoints.last.x, endX);
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

void assertPlotContainsNSegments(
  WidgetTester tester,
  dynamic numberOfSegments, {
  required String channelName,
}) {
  var pointSegments = _getChannelSegments(tester, channelName: channelName);
  expect(pointSegments.length, numberOfSegments);
}

int getSegmentCount(WidgetTester tester, {required String channelName}) {
  return _getChannelSegments(tester, channelName: channelName).length;
}

List<List<PlottingPoint>> _getChannelSegments(
  WidgetTester tester, {
  required String channelName,
}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;
  final pointSegments = plotState.points[channelName] ?? [];

  return pointSegments;
}

void assertPlotLoadingIndicator({required bool isVisible}) => expect(
  find.byType(LinearProgressIndicator),
  isVisible ? findsOneWidget : findsNothing,
);

List<PlottingPoint> _getPlotPoints(
  WidgetTester tester, {
  required String channelName,
  int segment = 0,
}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  return plotState.points[channelName]?[segment] ?? [];
}

LineChartBarData? _getLineChartBarData(
  WidgetTester tester, {
  int channelIndex = 0,
}) {
  final lineChartWidget =
      find.byType(LineChart).evaluate().first.widget as LineChart;
  final channels = lineChartWidget.data.lineBarsData;

  if (channelIndex >= channels.length) {
    return null;
  }

  return channels[channelIndex];
}

List<FlSpot> _getFlSpots(WidgetTester tester, {int channelIndex = 0}) {
  var lineBarsData = _getLineChartBarData(tester, channelIndex: channelIndex);

  if (lineBarsData == null) {
    return [];
  }

  return lineBarsData.spots;
}

Future<void> assertChannelIsBlinking(
  WidgetTester tester, {
  required int channelIndex,
  required bool blinking,
  Duration blinkChangeTimeout = const Duration(seconds: 2),
  Duration pumpInterval = const Duration(milliseconds: 50),
}) async {
  var data = _getLineChartBarData(tester, channelIndex: channelIndex);

  bool currentBlinkState = data!.color!.a == 1.0;

  LineChartBarData? updatedData;
  bool updatedBlinkState = currentBlinkState;

  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < blinkChangeTimeout) {
    await tester.pump(pumpInterval);

    updatedData = _getLineChartBarData(tester, channelIndex: channelIndex);
    updatedBlinkState = updatedData!.color!.a == 1.0;

    if (currentBlinkState != updatedBlinkState) {
      break;
    }
  }
  stopwatch.stop();

  if (blinking) {
    expect(currentBlinkState == updatedBlinkState, false);
  } else {
    expect(currentBlinkState == updatedBlinkState, true);
    // Line should not be dim in this mode.
    expect(currentBlinkState, true);
  }
}

Future<void> assertFlSpotsDifferent(
  WidgetTester tester, {
  required Future<void> Function() action,
  int channelIndex = 0,
}) async {
  final beforeSpots = _getFlSpots(tester, channelIndex: channelIndex);
  expect(beforeSpots.isNotEmpty, true);

  final beforeValues = beforeSpots.map((spot) => (spot.x, spot.y)).toList();

  await action();
  await tester.pumpAndSettle();

  final afterSpots = _getFlSpots(tester, channelIndex: channelIndex);
  expect(afterSpots.isNotEmpty, true);

  final afterValues = afterSpots.map((spot) => (spot.x, spot.y)).toList();

  bool foundDifference = false;

  if (beforeValues.length != afterValues.length) {
    foundDifference = true;
  } else {
    for (int i = 0; i < beforeValues.length; i++) {
      if (beforeValues[i].$1 != afterValues[i].$1 ||
          beforeValues[i].$2 != afterValues[i].$2) {
        foundDifference = true;
        break;
      }
    }
  }

  expect(
    foundDifference,
    true,
    reason: 'Expected FlSpots to be different after action',
  );
}

void assertFlSpotsDisplayed(WidgetTester tester, {required dynamic nPoints}) {
  final lineChartWidget =
      find.byType(LineChart).evaluate().first.widget as LineChart;
  final channels = lineChartWidget.data.lineBarsData;

  int totalPoints = 0;

  for (final channel in channels) {
    totalPoints += channel.spots.length;
  }
  expect(totalPoints, nPoints);
}

void assertAllFlSpotsAreNormal(WidgetTester tester) {
  final lineChartWidget =
      find.byType(LineChart).evaluate().first.widget as LineChart;
  final channels = lineChartWidget.data.lineBarsData;

  for (final channel in channels) {
    for (final spot in channel.spots) {
      expect(spot.y, inInclusiveRange(0.0, 1.0));
    }
  }
}

void assertNormalizedFlSpots(WidgetTester tester, List<List<double>> shouldBe) {
  final lineChartWidget =
      find.byType(LineChart).evaluate().first.widget as LineChart;
  final channels = lineChartWidget.data.lineBarsData;

  for (int channelIndex = 0; channelIndex != shouldBe.length; channelIndex++) {
    final channel = channels[channelIndex];
    for (
      int spotIndex = 0;
      spotIndex != shouldBe[channelIndex].length;
      spotIndex++
    ) {
      expect(
        channel.spots[spotIndex].y,
        moreOrLessEquals(shouldBe[channelIndex][spotIndex], epsilon: 0.01),
      );
    }
  }
}

void assertPlotYAxisLimitsLabel(
  WidgetTester tester, {
  required Color color,
  required String min,
  required String max,
}) {
  final allYAxisLabels = find.byType(PlotYAxisLabelWidget);
  final yAxisMax = allYAxisLabels.last;
  final yAxisMin = allYAxisLabels.first;

  expect(
    find.descendant(of: yAxisMax, matching: findTextWithColor(max, color)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: yAxisMin, matching: findTextWithColor(min, color)),
    findsOneWidget,
  );
}

Finder findTextWithColor(String text, Color color) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text && widget.data == text && widget.style?.color == color,
    description: 'Text widget with text "$text" and color $color',
  );
}
