import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';

/// A renderer-ready interval within one device's stacked bar.
class BarSegment {
  final String key;
  final String label;
  final double fromY;
  final double toY;
  final BarSegmentStyle style;

  const BarSegment({
    required this.key,
    required this.label,
    required this.fromY,
    required this.toY,
    required this.style,
  });
}
