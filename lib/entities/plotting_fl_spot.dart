import 'package:fl_chart/fl_chart.dart';

class PlottingFlSpot extends FlSpot {
  final double originalY;
  final _FlSpotExtension _ext = _FlSpotExtension();

  PlottingFlSpot(super.x, super.y) : originalY = y;

  @override
  // Returns the normalized Y value if it exists, otherwise returns the original Y value
  double get y => _ext._normalizedY ?? originalY;

  set normalizedY(double? value) => _ext._normalizedY = value;
}

// Additional class to ensure the flspot is immutable
class _FlSpotExtension {
  double? _normalizedY;
}
