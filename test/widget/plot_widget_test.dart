import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotWidget widget tests", () {
    testWidgets("Plot channel list is empty, plot is empty",
        (WidgetTester tester) async {
      // Given nothing
      // When I build the PlotWidget with an empty channel list
      await tester.pumpWidget(_buildPlotWidget(const []));
      await waitForPlotDataToLoad(tester);

      // Then the plot is empty
      assertEmptyPlot(isVisible: true);

      // ... and the Y-axis limits are 0 to 1
      assertPlotYAxisLimits(min: 0, max: 1);

      // ... and the X-axis limits are 0 to 1
      assertPlotXAxisLimits(min: 0, max: 1);
    });

    testWidgets("Plot PLOT TEST CONSTANT, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST CONSTANT"
      final channelList = ["PLOT TEST CONSTANT"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains 500 points with y = 5.0
      assertPlotContainsHorizontalLine(numberOfPoints: 500, atY: 5.0);

      // ... and the Y axis is labeled...
      assertPlotYAxisTitle(title: "PLOT TEST CONSTANT", units: "V");

      // ... and the Y-axis has limits of...
      assertPlotYAxisLimits(min: 0, max: 5);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST RAMP, get a ramp starting at Y=0.0 and ending at y = 500.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST RAMP"
      final channelList = ["PLOT TEST RAMP"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a ramp with 500 points starting at Y=0.0
      assertPlotContainsRamp(numberOfPoints: 500, startingAtY: 0.0);

      // ... and the Y-axis is labeled
      assertPlotYAxisTitle(title: "PLOT TEST RAMP", units: "V");

      // ... and the limits for the Y-axis are 0 to 500
      assertPlotYAxisLimits(min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA, get a parabola starting at X=-50 and ending at X=50",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = ["PLOT TEST PARABOLA"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(numberOfPoints: 501, startingAtX: -250);

      // ... and the Y-axis is labeled
      assertPlotYAxisTitle(title: "PLOT TEST PARABOLA", units: "V");

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a sine wave starting at X=-250 and ending at X=250",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = ["PLOT TEST SINE"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsSineWave(numberOfPoints: 501, startingAtX: -250);

      // ... and the Y-axis is labeled
      assertPlotYAxisTitle(title: "PLOT TEST SINE", units: "V");

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a progress indicator while data is fetched",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = ["PLOT TEST SINE"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));

      // Then I should see the progress indicator
      assertPlotLoadingIndicator(isVisible: true);
      await waitForPlotDataToLoad(tester);
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA 64K, get a parabola starting at X=-32767 and ending at X=32767",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = ["PLOT TEST PARABOLA 64K"];

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(numberOfPoints: 65535, startingAtX: -32767);

      // ... and the Y-axis is labeled
      assertPlotYAxisTitle(title: "PLOT TEST PARABOLA 64K", units: "V");

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(min: -32767.0, max: 32767.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets("Dismiss error message, error banner goes away",
        (WidgetTester tester) async {
      // Given I tried to plot a channel that had an error
      final channelList = ["PLOT TEST DOESN'T EXIST"];
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // When I dismiss the error banner
      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      // Then the error message is no longer visible
      expect(
          find.text(
              "An error occured when attempting to acquire data for PLOT TEST DOESN'T EXIST"),
          findsNothing);
    });

    testWidgets(
        "Dismiss error message, error banner goes away, can appear again",
        (WidgetTester tester) async {
      // Given I tried to plot a channel that had an error
      const errorChannel = "PLOT TEST DOESN'T EXIST";
      const errorMessage =
          "An error occured when attempting to acquire data for $errorChannel";
      List<String> channelList = [errorChannel];
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // When I dismiss the error banner
      expect(find.text(errorMessage), findsOne);
      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      // Then the error message is no longer visible
      expect(find.text(errorMessage), findsNothing);

      channelList.clear();
      channelList = [errorChannel];
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      expect(find.text(errorMessage), findsOne);
    });

    testWidgets("Plot API TEST CONST, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = ["API TEST CONSTANT"];

      // When I build the PlotWidget with an AcsysProvider
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsHorizontalLine(numberOfPoints: 500, atY: 5.0);

      // ... and the Y-axis is labeled
      assertPlotYAxisTitle(title: "API TEST CONSTANT", units: "A");

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(title: "Index");
    });

    testWidgets("Small screen, y-axis labels are on top",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = ["PLOT TEST CONSTANT"];

      // ... and we are rendering for a small display
      await setSmallScreenSize(tester);

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the y-axis labels are located on the top of the plot
      assertPlotYAxisTitle(title: "PLOT TEST CONSTANT", units: "V");
    });
  });
}

Widget _buildPlotWidget(List<String> channelList) => MaterialApp(
    home: Scaffold(
        body: ACSysProvider(
            service: FakeACSysService(),
            child: PlotWidget(
                plotChannels: channelList,
                daqService: const StandardPlotDAQ()))));

Future<void> waitForPlotDataToLoad(WidgetTester tester) async =>
    pumpUntilFound(tester, find.byType(LineChart));

void assertEmptyPlot({required bool isVisible}) {
  expect(find.byType(LineChart), isVisible ? findsOneWidget : findsNothing);

  if (isVisible) {
    final lineChart =
        (find.byType(LineChart).evaluate().first.widget as LineChart);

    expect(lineChart.data.lineBarsData.length, 1);
    expect(lineChart.data.lineBarsData.first.spots.isEmpty, true);
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

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  bool timerDone = false;
  final timer = Timer(timeout, () => timerDone = true);
  while (timerDone != true) {
    await tester.pumpAndSettle();

    final found = tester.any(finder);
    if (found) {
      timerDone = true;
    }
  }
  timer.cancel();
}

void assertPlotXAxisTitle({required String title}) => expect(
    find.descendant(of: find.byType(LineChart), matching: find.text(title)),
    findsOneWidget);

void assertPlotYAxisTitle({required String title, required String units}) {
  expect(
      find.descendant(of: find.byType(LineChart), matching: find.text(title)),
      findsOneWidget);

  expect(
      find.descendant(
          of: find.byType(LineChart), matching: find.text(" ($units)")),
      findsOneWidget);
}

void assertPlotContainsHorizontalLine(
    {required int numberOfPoints, required double atY}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints();
  for (int i = 0; i != numberOfPoints; i++) {
    expect(plotPoints[i].y, closeTo(atY, 0.01));
  }
}

void assertPlotContainsRamp(
    {required int numberOfPoints, required double startingAtY}) {
  assertPlotContainsNPoints(numberOfPoints);

  final plotPoints = _getPlotPoints();
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

void assertPlotContainsNPoints(int numberOfPoints) {
  final plotPoints = _getPlotPoints();

  expect(plotPoints.length, numberOfPoints);
}

void assertPlotLoadingIndicator({required bool isVisible}) => expect(
    find.byType(LinearProgressIndicator),
    isVisible ? findsOneWidget : findsNothing);

List<FlSpot> _getPlotPoints() =>
    (find.byType(LineChart).evaluate().first.widget as LineChart)
        .data
        .lineBarsData
        .first
        .spots;

void assertPlotConfigurationHasNoChannels() => expect(
    find.text("No channels.  Please add a channel to plot."), findsOneWidget);

void assertPlotConfigurationHasChannels(List<String> channels) {
  for (final deviceName in channels) {
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text(deviceName), matching: find.byType(Row)),
            matching: find.byIcon(Icons.delete)),
        findsOneWidget);
  }
}

Future<void> setSmallScreenSize(WidgetTester tester) async =>
    tester.binding.setSurfaceSize(const Size(375, 667));
