import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/widgets/fl_chart_bar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one stacked rod with red higher segment', (
    tester,
  ) async {
    final data = _data(current: 65, reference: 50);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const FlChartBarAdapter().build(context, data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rod = chart.data.barGroups.single.barRods.single;
    expect(chart.data.barGroups, hasLength(1));
    expect(rod.toY, 65);
    expect(rod.rodStackItems, hasLength(2));
    expect(rod.rodStackItems[0].fromY, 0);
    expect(rod.rodStackItems[0].toY, 50);
    expect(rod.rodStackItems[1].fromY, 50);
    expect(rod.rodStackItems[1].toY, 65);
    expect(rod.rodStackItems[1].color, const Color(0xFFF44336));
  });

  testWidgets('renders one stacked rod with green lower segment', (
    tester,
  ) async {
    final data = _data(current: 35, reference: 50);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const FlChartBarAdapter().build(context, data),
        ),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rod = chart.data.barGroups.single.barRods.single;
    expect(rod.toY, 50);
    expect(rod.rodStackItems, hasLength(2));
    expect(rod.rodStackItems[0].toY, 35);
    expect(rod.rodStackItems[1].fromY, 35);
    expect(rod.rodStackItems[1].toY, 50);
    expect(rod.rodStackItems[1].color, const Color(0xFF4CAF50));
  });
}

BarChartModel _data({required double current, required double reference}) {
  final reducer = BarChartReducer(
    deviceNames: ['Device A'],
    colorForDevice: (_) => Colors.blue,
  );
  reducer.setReference(device: 'Device A', value: reference);
  reducer.applyReply(_Reply(current));
  return reducer.data;
}

class _Reply {
  final List<_Channel> data;
  _Reply(double value) : data = [_Channel(value)];
}

class _Channel {
  final String name = 'Device A';
  final int status = 0;
  final String units = '';
  final List<_Point> points;
  _Channel(double value) : points = [_Point(value)];
}

class _Point {
  final double t = 1;
  final _Scalar value;
  _Point(double value) : value = _Scalar(value);
}

class _Scalar {
  final double value;
  _Scalar(this.value);
}
