import 'package:flutter/material.dart';

/// A single named contribution or explicit interval within one device's bar.
///
/// A segment created with [BarSegment.additive] contributes [value] after the
/// preceding segment. A segment created with [BarSegment.range] specifies its
/// own interval from [start] to [end]. When segments are stacked, ranges must
/// start exactly where the preceding segment ends; gaps and overlaps are
/// rejected by [BarChartModel.resolvedStackFor].
class BarSegment {
  /// Stable key identifying this segment within a device (e.g. `'value'`,
  /// `'setpoint'`). Used to update or remove the segment later.
  final String key;

  /// Human-readable label used by renderers and tooltips.
  final String label;

  /// Numeric contribution, or `null` when unavailable.
  ///
  /// This is set for segments created with [BarSegment.additive].
  final double? value;

  /// Explicit interval start. Both [start] and [end] are set only for segments
  /// created with [BarSegment.range].
  final double? start;

  /// Explicit interval end. Both [start] and [end] are set only for segments
  /// created with [BarSegment.range].
  final double? end;

  /// Color used to render this segment's bar.
  final Color color;

  /// Source timestamp, when supplied by the acquisition reply.
  final double? timestamp;

  /// Creates an additive segment. Prefer [BarSegment.additive] in new code.
  const BarSegment({
    required this.key,
    required this.label,
    required double value,
    required this.color,
    this.timestamp,
  }) : value = value,
       start = null,
       end = null;

  const BarSegment.additive({
    required this.key,
    required this.label,
    required double value,
    required this.color,
    this.timestamp,
  }) : value = value,
       start = null,
       end = null;

  const BarSegment.range({
    required this.key,
    required this.label,
    required double start,
    required double end,
    required this.color,
    this.timestamp,
  }) : value = null,
       start = start,
       end = end;

  /// Whether this segment contributes a value to the preceding segment end.
  bool get isAdditive => value != null;

  /// Whether this segment specifies its exact interval.
  bool get isRange => start != null && end != null;

  BarSegment copyWith({
    double? value,
    double? start,
    double? end,
    double? timestamp,
    Color? color,
  }) {
    if (isRange) {
      return BarSegment.range(
        key: key,
        label: label,
        start: start ?? this.start!,
        end: end ?? this.end!,
        color: color ?? this.color,
        timestamp: timestamp ?? this.timestamp,
      );
    }
    return BarSegment.additive(
      key: key,
      label: label,
      value: value ?? this.value!,
      color: color ?? this.color,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
