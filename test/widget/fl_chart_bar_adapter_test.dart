import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/widgets/fl_chart_bar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one independent rod per device segment', (tester) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      colorForDevice: (_) => Colors.blue,
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'setpoint',
      label: 'Setpoint',
      value: 50,
      color: Colors.grey,
    );
    reducer.applyReply(_reply('Device A', 65));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final group = chart.data.barGroups.single;
    expect(chart.data.barGroups, hasLength(1));
    expect(group.barRods, hasLength(2));
    expect(group.barRods[0].toY, 50);
    expect(group.barRods[0].color, Colors.grey);
    expect(group.barRods[1].toY, 65);
  });

  testWidgets('renders one group per device with its own segment count', (
    tester,
  ) async {
    final reducer = BarChartReducer(
      deviceNames: ['A', 'B'],
      colorForDevice: (_) => Colors.blue,
    );
    reducer.applyReply(_reply('A', 10));
    reducer.applyReply(_reply('B', 20));
    reducer.setSegment(device: 'B', key: 'limit', label: 'Limit', value: 30);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(2));
    expect(chart.data.barGroups[0].barRods, hasLength(1));
    expect(chart.data.barGroups[1].barRods, hasLength(2));
  });

  testWidgets('applies style layout knobs to rendered bars', (tester) async {
    final reducer = BarChartReducer(
      deviceNames: ['A'],
      colorForDevice: (_) => Colors.blue,
      style: const BarChartStyle(segmentWidth: 30),
    );
    reducer.applyReply(_reply('A', 5));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.single.barRods.single.width, 30);
  });
}

PlotReply _reply(String device, double value) => PlotReply(
  plotId: 'test',
  xAxisUnits: '',
  xAxisMin: 0,
  xAxisMax: 1,
  windowSize: 1,
  requestTime: 1,
  data: [
    PlotChannelData(
      name: device,
      units: '',
      rate: '',
      status: 0,
      points: [PlotPoint(t: 1, value: DevScalar(value))],
    ),
  ],
);
