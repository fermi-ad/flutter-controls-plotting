import 'package:fl_chart/fl_chart.dart';

class PlottingFlSpot extends FlSpot {
  final double originalY;
  final double? _normalizedY;

  const PlottingFlSpot(super.x, super.y) : originalY = y, _normalizedY = null;

  const PlottingFlSpot._normalized(
    double x,
    this.originalY,
    double? normalizedY,
  ) : _normalizedY = normalizedY,
      super(x, normalizedY ?? originalY);

  @override
  // Returns the normalized Y value if it exists, otherwise returns the original Y value
  double get y => _normalizedY ?? originalY;

  /// Returns a new spot with the given normalized Y value.
  PlottingFlSpot withNormalizedY(double? value) =>
      PlottingFlSpot._normalized(x, originalY, value);
}
