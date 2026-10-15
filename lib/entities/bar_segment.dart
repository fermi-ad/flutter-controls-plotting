import 'package:flutter/material.dart';

/// A single named contribution or explicit interval within one device's bar.
///
/// In grouped layout, an additive segment is drawn from zero to [value]. In
/// stacked layout, it contributes [value] after the preceding segment on its
/// signed side of zero. [BarSegment.range] specifies an interval from [start]
/// to [end] for stacked rendering; the current grouped renderer does not draw
/// explicit ranges.
///
/// Stack resolution requires ranges to begin at the preceding end on the same
/// signed side, within an absolute tolerance of 1e-9, and extend away from zero.
/// It rejects gaps, overlaps, non-finite bounds, and ranges crossing zero.
/// Constructors themselves do not validate numeric values or range continuity.
class BarSegment {
  /// Stable key identifying this segment within a device (e.g. `'value'`,
  /// `'setpoint'`). Used to update or remove the segment later.
  final String key;

  /// Human-readable label used by renderers and tooltips.
  final String label;

  /// Numeric contribution for an additive segment, or `null` for a range.
  ///
  /// Additive constructors also accept `null` to represent an unavailable value.
  /// Such a segment cannot be resolved as part of a stack.
  final double? value;

  /// Explicit interval start. Both [start] and [end] are set only for segments
  /// created with [BarSegment.range].
  final double? start;

  /// Explicit interval end. Both [start] and [end] are set only for segments
  /// created with [BarSegment.range].
  final double? end;

  /// Color used to render this segment's bar.
  final Color color;

  /// Source point timestamp in the acquisition service's time convention.
  ///
  /// Manual controller edits leave this unset. For a time-series reply, this
  /// is the containing plot point's timestamp, not the extracted sample's time.
  final double? timestamp;

  /// Creates an additive segment. Prefer [BarSegment.additive] in new code.
  const BarSegment({
    required this.key,
    required this.label,
    required this.value,
    required this.color,
    this.timestamp,
  }) : start = null,
       end = null;

  /// Creates a numeric contribution without validating its value.
  ///
  /// A null [value] represents unavailable data and is invalid in a stack.
  const BarSegment.additive({
    required this.key,
    required this.label,
    required this.value,
    required this.color,
    this.timestamp,
  }) : start = null,
       end = null;

  /// Creates an explicit interval without validating its bounds or continuity.
  ///
  /// Both bounds must be finite and non-null when resolved in a stack.
  const BarSegment.range({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
    required this.color,
    this.timestamp,
  }) : value = null;

  /// Whether a non-null additive value is available, regardless of finiteness.
  bool get isAdditive => value != null;

  /// Whether both explicit bounds are present, regardless of their validity.
  bool get isRange => start != null && end != null;

  /// Copies this segment, preserving its key, label, and representation.
  ///
  /// Null arguments retain existing values, so this cannot clear a timestamp
  /// or bound. For a range, [value] is ignored; for an additive segment, [start]
  /// and [end] are ignored. An unavailable additive value must be replaced with
  /// a non-null [value] to copy it. The result is not validated.
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
