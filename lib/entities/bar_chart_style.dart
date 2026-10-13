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

  /// Renders segments as contiguous signed portions of one rod per device.
  ///
  /// Positive and negative contributions accumulate independently from zero.
  stacked,
}

/// Renderer-neutral presentation settings for device bar groups.
///
/// This library renders whatever segments the caller supplies for each
/// device — it does not derive additional segments or interpret their
/// meaning. Settings control axis bounds and labels, grouped or stacked layout,
/// bar geometry, spacing, and fallback color. Renderers translate these settings
/// into their plotting package's geometry and interaction behavior.
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
  /// [BarChartLayout.grouped] draws additive values independently from zero.
  /// In [BarChartLayout.stacked], positive and negative segments accumulate
  /// independently from zero with no gaps or overlaps on either signed side.
  /// Explicit ranges are supported by the current renderer only when stacked.
  final BarChartLayout layout;

  /// Bar width in logical pixels, per segment when grouped or per device stack.
  final double segmentWidth;

  /// Spacing in logical pixels between grouped segments; unused for stacks.
  final double segmentSpace;

  /// Requested spacing in logical pixels between different devices' groups.
  ///
  /// The renderer's group alignment may also distribute available chart space.
  final double groupSpace;

  /// Corner rounding applied to each grouped bar or the outer stacked rod.
  final BorderRadius borderRadius;

  /// Fallback color used by the reducer when no explicit segment color or
  /// device color resolver is supplied.
  final Color defaultColor;

  /// Creates immutable presentation settings with grouped bars by default.
  ///
  /// Asserts that paired Y bounds are increasing and [yAxisDivisions], when
  /// supplied, is positive. These assertions are disabled in release builds.
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
