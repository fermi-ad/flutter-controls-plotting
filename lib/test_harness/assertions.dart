import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
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

void assertColorOfPlot({required Color expectedColor}) {
  expect(find.byType(LineChart), findsOneWidget);
  final lineChart =
      (find.byType(LineChart).evaluate().first.widget as LineChart);

  expect(lineChart.data.lineBarsData.first.color, expectedColor);
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

void assertDifferentColorsYAxisLabels(
    {required int expectedLabelCount, String title = 'PLOT TEST'}) {
  var yLabels = find.descendant(
      of: find.byType(LineChart), matching: find.textContaining(title));
  expect(yLabels, findsExactly(expectedLabelCount));

  var uniqueColors = [];

  for (var yLabel in yLabels.found) {
    Text label = yLabel.widget as Text;
    var color = label.style?.color;
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

void assertPlotYAxisLimits(WidgetTester tester,
    {required double min, required double max}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  expect(plotState.minY, closeTo(min, 0.01));
  expect(plotState.maxY, closeTo(max, 0.01));
}

void assertPlotContainsHorizontalLine(WidgetTester tester,
    {required int numberOfPoints, required double atY, int lineBarIndex = 0}) {
  assertPlotContainsNPoints(tester, numberOfPoints);

  final plotPoints = _getPlotPoints(tester, lineBarIndex: lineBarIndex);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(atY, 0.01));
  }
}

void assertPlotContainsRamp(WidgetTester tester,
    {required int numberOfPoints,
    required double startingAtY,
    int lineBarIndex = 0}) {
  assertPlotContainsNPoints(tester, numberOfPoints);

  final plotPoints = _getPlotPoints(tester, lineBarIndex: lineBarIndex);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(startingAtY + i, 0.01));
  }
}

void assertPlotContainsParabola(WidgetTester tester,
    {required int numberOfPoints, required double startingAtX}) {
  assertPlotContainsNPoints(tester, numberOfPoints);

  final plotPoints = _getPlotPoints(tester);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(pow(x, 2), 0.01));
  }
}

void assertPlotContainsSineWave(WidgetTester tester,
    {required int numberOfPoints, required int startingAtX}) {
  assertPlotContainsNPoints(tester, numberOfPoints);

  final plotPoints = _getPlotPoints(tester);
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(sin(x * 6.28 / 500), 0.01));
  }
}

void assertPlotContainsNormalDistribution(WidgetTester tester,
    {required int numberOfPoints, required int centeredAtX}) {
  assertPlotContainsNPoints(tester, numberOfPoints);

  final plotPoints = _getPlotPoints(tester);
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

void assertPlotContainsNPoints(WidgetTester tester, int numberOfPoints) {
  final plotPoints = _getPlotPoints(tester);

  expect(plotPoints.length, numberOfPoints);
}

void assertPlotLoadingIndicator({required bool isVisible}) => expect(
    find.byType(LinearProgressIndicator),
    isVisible ? findsOneWidget : findsNothing);

List<PlotPoint> _getPlotPoints(WidgetTester tester, {int lineBarIndex = 0}) {
  final plotState = tester.state(find.byType(PlotWidget)) as PlotState;

  return plotState.points[lineBarIndex];
}
