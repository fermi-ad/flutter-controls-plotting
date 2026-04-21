import 'package:fl_chart/fl_chart.dart';

class PlottingFlSpot extends FlSpot {
  final double originalY;
  final double? _normalizedY;

  PlottingFlSpot(double x, double y)
    : originalY = y,
      _normalizedY = null,
      super(x, y);

  const PlottingFlSpot._normalized(
    double x,
    double originalY,
    double? normalizedY,
  ) : originalY = originalY,
      _normalizedY = normalizedY,
      super(x, normalizedY ?? originalY);

  @override
  // Returns the normalized Y value if it exists, otherwise returns the original Y value
  double get y => _normalizedY ?? originalY;

  /// Returns a new spot with the given normalized Y value.
  PlottingFlSpot withNormalizedY(double? value) =>
      PlottingFlSpot._normalized(x, originalY, value);
}
