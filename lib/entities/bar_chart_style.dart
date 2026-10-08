import 'package:flutter/material.dart';

/// Formats one numeric Y-axis tick value for display.
///
/// When omitted, the active chart renderer chooses a precision that preserves
/// meaningful fractional differences between adjacent tick values.
typedef BarYAxisLabelFormatter = String Function(double value);

/// Determines how a device's segments are arranged.
enum BarChartLayout {
  /// Renders every segment as an independent rod next to the other segments.
  grouped,

  /// Renders all segments for a device as contiguous portions of one rod.
  stacked,
}

/// Renderer-neutral presentation settings for device bar groups.
///
/// This library renders whatever segments the caller supplies for each
/// device — it does not derive additional segments or interpret their
/// meaning. [BarChartStyle] only controls layout and the color used when
/// a segment or device does not specify its own color.
class BarChartStyle {
  /// Fixed lower Y bound, or `null` to auto-scale from the data.
  ///
  /// When both bounds are set, renderers display only the geometry within this
  /// inclusive range while preserving raw values for interaction details.
  final double? minY;

  /// Fixed upper Y bound, or `null` to auto-scale from the data.
  ///
  /// When both bounds are set, renderers display only the geometry within this
  /// inclusive range while preserving raw values for interaction details.
  final double? maxY;

  /// Number of equal Y-axis intervals across the visible Y range.
  ///
  /// When `null`, the renderer chooses axis ticks automatically. A value of
  /// `n` produces `n + 1` tick positions including both axis bounds.
  final int? yAxisDivisions;

  /// Formats Y-axis tick values, or `null` for precision-aware automatic
  /// formatting.
  final BarYAxisLabelFormatter? yAxisLabelFormatter;

  /// Rotation, in degrees, applied to X-axis device labels.
  ///
  /// Positive values rotate clockwise in the renderer's coordinate system.
  final double xAxisLabelRotation;

  /// Whether axis titles (device names, Y labels) are shown.
  final bool showTitles;

  /// Arrangement used to render the segments within each device group.
  ///
  /// [BarChartLayout.grouped] preserves the original behavior. In
  /// [BarChartLayout.stacked] mode, every device's segments must resolve to
  /// contiguous intervals with no overlaps or gaps.
  final BarChartLayout layout;

  /// Width of each individual segment's bar.
  final double segmentWidth;

  /// Spacing between segments within the same device's group.
  final double segmentSpace;

  /// Spacing between different devices' groups.
  final double groupSpace;

  /// Corner rounding applied to each segment's bar.
  final BorderRadius borderRadius;

  /// Fallback color used for a segment when neither the segment itself nor
  /// a `colorForDevice`/`colorForSegment` callback supplies one.
  final Color defaultColor;

  const BarChartStyle({
    this.minY,
    this.maxY,
    this.yAxisDivisions,
    this.yAxisLabelFormatter,
    this.xAxisLabelRotation = 0,
    this.showTitles = true,
    this.layout = BarChartLayout.grouped,
    this.segmentWidth = 18,
    this.segmentSpace = 4,
    this.groupSpace = 12,
    this.borderRadius = BorderRadius.zero,
    this.defaultColor = const Color(0xFF2196F3),
  }) : assert(minY == null || maxY == null || minY < maxY),
       assert(yAxisDivisions == null || yAxisDivisions > 0);
}
