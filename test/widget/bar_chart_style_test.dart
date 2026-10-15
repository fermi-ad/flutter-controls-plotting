import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarChartStyle', () {
    test('preserves the automatic-axis defaults', () {
      const style = BarChartStyle();

      expect(style.yAxisDivisions, isNull);
      expect(style.yAxisLabelFormatter, isNull);
      expect(style.xAxisLabelRotation, 0);
    });

    test('stores explicit axis presentation settings', () {
      String format(double value) => '${value.toStringAsFixed(2)} A';
      final style = BarChartStyle(
        yAxisDivisions: 4,
        xAxisLabelRotation: 45,
        yAxisLabelFormatter: format,
      );

      expect(style.yAxisDivisions, 4);
      expect(style.xAxisLabelRotation, 45);
      expect(style.yAxisLabelFormatter!(1.25), '1.25 A');
    });

    test('rejects non-positive Y-axis division counts', () {
      expect(() => BarChartStyle(yAxisDivisions: 0), throwsAssertionError);
      expect(() => BarChartStyle(yAxisDivisions: -1), throwsAssertionError);
    });

    test('rejects equal or reversed fixed Y bounds', () {
      expect(() => BarChartStyle(minY: 2, maxY: 2), throwsAssertionError);
      expect(() => BarChartStyle(minY: 3, maxY: 2), throwsAssertionError);
    });
  });
}
