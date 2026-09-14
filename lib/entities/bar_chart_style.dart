import 'package:flutter/material.dart';

/// Styling for a named segment in a device bar.
class BarSegmentStyle {
  final Color color;
  final Color? borderColor;
  final double? borderWidth;

  const BarSegmentStyle({
    required this.color,
    this.borderColor,
    this.borderWidth,
  });
}

/// Renderer-neutral presentation settings for device bars.
class BarChartStyle {
  final Map<String, BarSegmentStyle> segmentStyles;
  final BarSegmentStyle defaultSegmentStyle;
  final double? minY;
  final double? maxY;
  final bool showTitles;
  final double rodWidth;
  final BorderRadius borderRadius;

  const BarChartStyle({
    this.segmentStyles = const {
      'current': BarSegmentStyle(color: Color(0xFF2196F3)),
      'reference': BarSegmentStyle(color: Color(0xFF9E9E9E)),
      'higher': BarSegmentStyle(color: Color(0xFFF44336)),
      'lower': BarSegmentStyle(color: Color(0xFF4CAF50)),
    },
    this.defaultSegmentStyle = const BarSegmentStyle(color: Color(0xFF2196F3)),
    this.minY,
    this.maxY,
    this.showTitles = true,
    this.rodWidth = 18,
    this.borderRadius = BorderRadius.zero,
  });

  BarSegmentStyle styleFor(String key) =>
      segmentStyles[key] ?? defaultSegmentStyle;
}
