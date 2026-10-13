import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';

/// Rendering boundary for categorical device bar charts.
///
/// Implementations consume a [BarChartModel] snapshot and return a chart widget,
/// preserving device and segment order. They should not acquire data, mutate
/// the model, or assign domain meaning to segment keys. This keeps acquisition
/// and segment management independent of a plotting package.
abstract class BarChartAdapter {
  /// Creates a renderer boundary without acquiring data or owning a controller.
  const BarChartAdapter();

  /// Builds a chart for the current renderer-neutral [data] snapshot.
  ///
  /// Implementations interpret its style, units, and channel errors. Empty
  /// device groups are valid. Stacked renderers should resolve intervals via
  /// [BarChartModel.resolvedStackFor], which can throw for invalid source data.
  Widget build(BuildContext context, BarChartModel data);
}
