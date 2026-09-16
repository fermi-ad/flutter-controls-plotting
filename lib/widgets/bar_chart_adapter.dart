import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';

/// Rendering boundary for categorical device bar charts.
///
/// Implementations should consume only [BarChartModel] and return the
/// corresponding chart widget. This keeps acquisition, reference management,
/// and comparison semantics independent of a plotting package.
abstract class BarChartAdapter {
  const BarChartAdapter();

  /// Builds a chart for the current renderer-neutral [data] snapshot.
  Widget build(BuildContext context, BarChartModel data);
}
