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

  testWidgets('renders contiguous segments as one stacked rod', (tester) async {
    final reducer = BarChartReducer(
      deviceNames: ['A', 'B'],
      style: const BarChartStyle(layout: BarChartLayout.stacked),
    );
    reducer.setSegment(
      device: 'A',
      key: 'first',
      label: 'First',
      value: 2,
      color: Colors.red,
    );
    reducer.setRangeSegment(
      device: 'A',
      key: 'second',
      label: 'Second',
      start: 2,
      end: 5,
      color: Colors.blue,
    );
    reducer.setSegment(
      device: 'B',
      key: 'only',
      label: 'Only',
      value: 7,
      color: Colors.green,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final firstRod = chart.data.barGroups[0].barRods.single;
    final secondRod = chart.data.barGroups[1].barRods.single;
    expect(firstRod.toY, 5);
    expect(firstRod.rodStackItems, hasLength(2));
    expect(firstRod.rodStackItems[0].fromY, 0);
    expect(firstRod.rodStackItems[0].toY, 2);
    expect(firstRod.rodStackItems[0].color, Colors.red);
    expect(firstRod.rodStackItems[1].fromY, 2);
    expect(firstRod.rodStackItems[1].toY, 5);
    expect(firstRod.rodStackItems[1].color, Colors.blue);
    expect(secondRod.toY, 7);
    expect(secondRod.rodStackItems, hasLength(1));
    expect(chart.data.maxY, greaterThan(7));
  });

  testWidgets('renders positive and negative stacks from zero', (tester) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      style: const BarChartStyle(layout: BarChartLayout.stacked),
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'up',
      label: 'Up',
      value: 2,
      color: Colors.red,
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'down',
      label: 'Down',
      value: -3,
      color: Colors.blue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final rod = tester
        .widget<BarChart>(find.byType(BarChart))
        .data
        .barGroups
        .single
        .barRods
        .single;
    expect(rod.fromY, -3);
    expect(rod.toY, 2);
    expect(rod.rodStackItems[0].fromY, 0);
    expect(rod.rodStackItems[0].toY, 2);
    expect(rod.rodStackItems[1].fromY, 0);
    expect(rod.rodStackItems[1].toY, -3);
  });

  testWidgets('clips grouped rods to fixed Y limits', (tester) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      style: const BarChartStyle(minY: -1, maxY: 1),
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'high',
      label: 'High',
      value: 3,
    );
    reducer.setSegment(device: 'Device A', key: 'low', label: 'Low', value: -2);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final rods = tester
        .widget<BarChart>(find.byType(BarChart))
        .data
        .barGroups
        .single
        .barRods;
    expect(rods, hasLength(2));
    expect(rods[0].fromY, 0);
    expect(rods[0].toY, 1);
    expect(rods[1].fromY, 0);
    expect(rods[1].toY, -1);
  });

  testWidgets('clips stacked geometry while preserving raw tooltip values', (
    tester,
  ) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      style: const BarChartStyle(
        layout: BarChartLayout.stacked,
        minY: 0,
        maxY: 3,
      ),
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'first',
      label: 'First',
      value: 2,
      color: Colors.red,
    );
    reducer.setSegment(
      device: 'Device A',
      key: 'second',
      label: 'Second',
      value: 3,
      color: Colors.blue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rod = chart.data.barGroups.single.barRods.single;
    final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
      chart.data.barGroups.single,
      0,
      rod,
      0,
    );

    expect(rod.rodStackItems[0].fromY, 0);
    expect(rod.rodStackItems[0].toY, 2);
    expect(rod.rodStackItems[1].fromY, 2);
    expect(rod.rodStackItems[1].toY, 3);
    expect(tooltip!.text, contains('2.000–5.000'));
  });

  testWidgets('formats fractional Y labels without collapsing values', (
    tester,
  ) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      style: const BarChartStyle(minY: 0, maxY: 0.4, yAxisDivisions: 4),
    );
    reducer.applyReply(_reply('Device A', 0.2));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final yTitle = chart.data.titlesData.leftTitles.sideTitles.getTitlesWidget(
      0.1,
      _titleMeta(),
    );

    expect((yTitle as SideTitleWidget).child, isA<Text>());
    expect((yTitle.child as Text).data, '0.1');
  });

  testWidgets('uses configured Y divisions, label formatter, and X rotation', (
    tester,
  ) async {
    final reducer = BarChartReducer(
      deviceNames: ['Device A'],
      style: BarChartStyle(
        minY: 0,
        maxY: 1,
        yAxisDivisions: 4,
        xAxisLabelRotation: 45,
        yAxisLabelFormatter: (value) => '${value.toStringAsFixed(2)} V',
      ),
    );
    reducer.applyReply(_reply('Device A', 0.5));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              const FlChartBarAdapter().build(context, reducer.data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final leftTitles = chart.data.titlesData.leftTitles.sideTitles;
    final bottomTitles = chart.data.titlesData.bottomTitles.sideTitles;
    final yTitle = leftTitles.getTitlesWidget(0.25, _titleMeta());
    final xTitle = bottomTitles.getTitlesWidget(0, _titleMeta());

    expect(leftTitles.interval, 0.25);
    expect((yTitle as SideTitleWidget).child, isA<Text>());
    expect(((yTitle.child as Text).data), '0.25 V');
    expect((xTitle as SideTitleWidget).angle, closeTo(0.785398, 0.000001));
    expect(bottomTitles.reservedSize, 72);
  });
}

TitleMeta _titleMeta() => TitleMeta(
  min: 0,
  max: 1,
  parentAxisSize: 100,
  axisPosition: 0,
  appliedInterval: 1,
  sideTitles: SideTitles(),
  formattedValue: '',
  axisSide: AxisSide.bottom,
  rotationQuarterTurns: 0,
);

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
