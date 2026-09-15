import 'package:flutter/material.dart';

/// Renderer-neutral presentation settings for device bar groups.
///
/// This library renders whatever segments the caller supplies for each
/// device — it does not derive additional segments or interpret their
/// meaning. [BarChartStyle] only controls layout and the color used when
/// a segment or device does not specify its own color.
class BarChartStyle {
  /// Fixed lower Y bound, or `null` to auto-scale from the data.
  final double? minY;

  /// Fixed upper Y bound, or `null` to auto-scale from the data.
  final double? maxY;

  /// Whether axis titles (device names, Y labels) are shown.
  final bool showTitles;

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
    this.showTitles = true,
    this.segmentWidth = 18,
    this.segmentSpace = 4,
    this.groupSpace = 12,
    this.borderRadius = BorderRadius.zero,
    this.defaultColor = const Color(0xFF2196F3),
  });
}
