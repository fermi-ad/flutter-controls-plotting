import 'dart:async';

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
