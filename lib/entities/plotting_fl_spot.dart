import 'package:fl_chart/fl_chart.dart';

class PlottingFlSpot extends FlSpot {
  final double originalY;
  double? _normalizedY;

  PlottingFlSpot(super.x, super.y) : originalY = y;

  @override
  // Returns the normalized Y value if it exists, otherwise returns the original Y value
  double get y => _normalizedY ?? originalY;

  set normalizedY(double? value) => _normalizedY = value;
}
