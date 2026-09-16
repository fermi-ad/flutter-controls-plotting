import 'package:flutter/material.dart';

/// A single named, independently rendered value within one device's bar
/// group.
///
/// Each device can have any number of segments — for example a live reading,
/// a setpoint, and a limit — each rendered as its own bar next to the
/// others. This library does not derive segments from one another; callers
/// decide what each segment means and supply its value directly.
class BarSegment {
  /// Stable key identifying this segment within a device (e.g. `'value'`,
  /// `'setpoint'`). Used to update or remove the segment later.
  final String key;

  /// Human-readable label used by renderers and tooltips.
  final String label;

  /// Numeric value, or `null` when unavailable (renders as an empty bar).
  final double? value;

  /// Color used to render this segment's bar.
  final Color color;

  /// Source timestamp, when supplied by the acquisition reply.
  final double? timestamp;

  const BarSegment({
    required this.key,
    required this.label,
    required this.value,
    required this.color,
    this.timestamp,
  });

  BarSegment copyWith({double? value, double? timestamp, Color? color}) {
    return BarSegment(
      key: key,
      label: label,
      value: value ?? this.value,
      color: color ?? this.color,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
