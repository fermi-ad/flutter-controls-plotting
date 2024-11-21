import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void assertEmptyPlot({required bool isVisible}) {
  expect(find.byType(LineChart), isVisible ? findsOneWidget : findsNothing);

  if (isVisible) {
    final lineChart =
        (find.byType(LineChart).evaluate().first.widget as LineChart);

    expect(lineChart.data.lineBarsData.length, 0);
  }
}

void assertColorOfPlot({required Color expectedColor}) {
  expect(find.byType(LineChart), findsOneWidget);  
  final lineChart =
      (find.byType(LineChart).evaluate().first.widget as LineChart);
      
  expect(lineChart.data.lineBarsData.first.color, expectedColor);  
}

void assertPlotXAxisTitle({required String title}) => expect(
    find.descendant(of: find.byType(LineChart), matching: find.text(title)),
    findsOneWidget);

void assertPlotYAxisTitle(
    {required String title, required String units, int sameUnitCount = 1}) {
  expect(
      find.descendant(of: find.byType(LineChart), matching: find.text(title)),
      findsOneWidget);

  expect(
      find.descendant(
          of: find.byType(LineChart), matching: find.text(" ($units)")),
      findsExactly(sameUnitCount));
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

void assertPlotXAxisLimits({required double min, required double max}) {
  final lineChartData =
      (find.byType(LineChart).evaluate().first.widget as LineChart).data;

  expect(lineChartData.minX, closeTo(min, 0.01));
  expect(lineChartData.maxX, closeTo(max, 0.01));
}

void assertPlotYAxisLimits({required double min, required double max}) {
  final lineChartData =
      (find.byType(LineChart).evaluate().first.widget as LineChart).data;

  expect(lineChartData.minY, closeTo(min, 0.01));
  expect(lineChartData.maxY, closeTo(max, 0.01));
}

void assertPlotContainsHorizontalLine(
    {required int numberOfPoints, required double atY, int lineBarIndex = 0}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints(lineBarIndex: lineBarIndex);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(atY, 0.01));
  }
}

void assertPlotContainsRamp(
    {required int numberOfPoints,
    required double startingAtY,
    int lineBarIndex = 0}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints(lineBarIndex: lineBarIndex);
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(startingAtY + i, 0.01));
  }
}

void assertPlotContainsParabola(
    {required int numberOfPoints, required double startingAtX}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints();
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(pow(x, 2), 0.01));
  }
}

void assertPlotContainsSineWave(
    {required int numberOfPoints, required int startingAtX}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints();
  for (int i = 0; i != numberOfPoints; i++) {
    final x = startingAtX + i;
    expect(plotPoints[i].y, closeTo(sin(x * 6.28 / 500), 0.01));
  }
}

void assertPlotContainsNormalDistribution(
    {required int numberOfPoints, required int centeredAtX}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints();
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

void assertPlotContainsNPoints(int numberOfPoints) {
  final plotPoints = _getPlotPoints();

  expect(plotPoints.length, numberOfPoints);
}

void assertPlotLoadingIndicator({required bool isVisible}) => expect(
    find.byType(LinearProgressIndicator),
    isVisible ? findsOneWidget : findsNothing);

List<FlSpot> _getPlotPoints({int lineBarIndex = 0}) {
  return (find.byType(LineChart).evaluate().first.widget as LineChart)
      .data
      .lineBarsData[lineBarIndex]
      .spots;
}
