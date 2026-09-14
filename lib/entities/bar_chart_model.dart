import 'dart:ui';

import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment.dart';
import 'package:flutter_controls_plotting/entities/bar_segment_policy.dart';

/// Direction of the current reading relative to its reference.
enum BarChangeDirection { unchanged, higher, lower }

/// Renderer-neutral comparison interval for one device.
///
/// When [reference] is present, [barEnd] is the visible bar height. For a
/// lower current value, the bar remains at the reference height and the
/// interval from [current] to [reference] represents the green decrease.
class BarComparison {
  /// Latest reading received for the device.
  final double current;

  /// Captured baseline, or `null` when no reference exists.
  final double? reference;

  /// End of the neutral/base interval.
  final double baseEnd;

  /// Total visible bar endpoint.
  final double barEnd;

  /// Relationship between [current] and [reference].
  final BarChangeDirection direction;

  /// Signed difference, calculated as `current - reference`.
  final double delta;

  const BarComparison({
    required this.current,
    required this.reference,
    required this.baseEnd,
    required this.barEnd,
    required this.direction,
    required this.delta,
  });
}

/// A named value displayed as one rod in a device's bar group.
class BarValue {
  /// Stable semantic key, such as `current` or `reference`.
  final String key;

  /// Human-readable label used by renderers and tooltips.
  final String label;

  /// Numeric value, or `null` when unavailable.
  final double? value;

  /// Default color for this value when no comparison stack is active.
  final Color color;

  /// Source timestamp, when supplied by the acquisition reply.
  final double? timestamp;

  const BarValue({
    required this.key,
    required this.label,
    required this.value,
    required this.color,
    this.timestamp,
  });

  BarValue copyWith({double? value, double? timestamp, Color? color}) {
    return BarValue(
      key: key,
      label: label,
      value: value ?? this.value,
      color: color ?? this.color,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Renderer-neutral state for categorical device bars.
///
/// Device order is preserved from [deviceNames]. Values are keyed by their
/// semantic value key. Stream replies update current values while retaining
/// existing values for devices omitted from partial replies.
class BarChartModel {
  /// Policy used to convert named values into renderable segments.
  final BarSegmentPolicy segmentPolicy;

  /// Style passed to [segmentPolicy] and the renderer.
  final BarChartStyle style;

  /// Stable X-axis category order.
  final List<String> deviceNames;

  /// Named values indexed by device name and value key.
  final Map<String, Map<String, BarValue>> valuesByDevice;

  /// Units indexed by device name.
  final Map<String, String> unitsByDevice;

  /// Latest channel errors indexed by device name.
  final Map<String, String> errorsByDevice;

  const BarChartModel({
    required this.deviceNames,
    required this.valuesByDevice,
    this.unitsByDevice = const {},
    this.errorsByDevice = const {},
    this.segmentPolicy = const ReferenceDeltaSegmentPolicy(),
    this.style = const BarChartStyle(),
  });

  BarChartModel.empty({List<String> devices = const []})
    : deviceNames = List.unmodifiable(devices),
      valuesByDevice = const {},
      unitsByDevice = const {},
      errorsByDevice = const {},
      segmentPolicy = const ReferenceDeltaSegmentPolicy(),
      style = const BarChartStyle();

  /// Returns all named values currently available for [device].
  List<BarValue> valuesFor(String device) =>
      (valuesByDevice[device]?.values ?? const <BarValue>[]).toList();

  /// Returns one named value for [device], if available.
  BarValue? valueFor(String device, String valueKey) =>
      valuesByDevice[device]?[valueKey];

  /// Derives the stacked reference/change intervals for [device].
  BarComparison? comparisonFor(String device) {
    final current = valueFor(device, 'current')?.value;
    if (current == null) return null;
    final reference = valueFor(device, 'reference')?.value;
    if (reference == null) {
      return BarComparison(
        current: current,
        reference: null,
        baseEnd: current,
        barEnd: current,
        direction: BarChangeDirection.unchanged,
        delta: 0,
      );
    }

    final delta = current - reference;
    final direction = delta == 0
        ? BarChangeDirection.unchanged
        : delta > 0
        ? BarChangeDirection.higher
        : BarChangeDirection.lower;
    return BarComparison(
      current: current,
      reference: reference,
      baseEnd: direction == BarChangeDirection.lower ? current : reference,
      barEnd: direction == BarChangeDirection.lower ? reference : current,
      direction: direction,
      delta: delta,
    );
  }

  BarChartModel copyWith({
    List<String>? deviceNames,
    Map<String, Map<String, BarValue>>? valuesByDevice,
    Map<String, String>? unitsByDevice,
    Map<String, String>? errorsByDevice,
    BarSegmentPolicy? segmentPolicy,
    BarChartStyle? style,
  }) {
    return BarChartModel(
      deviceNames: List.unmodifiable(deviceNames ?? this.deviceNames),
      valuesByDevice: valuesByDevice ?? this.valuesByDevice,
      unitsByDevice: unitsByDevice ?? this.unitsByDevice,
      errorsByDevice: errorsByDevice ?? this.errorsByDevice,
      segmentPolicy: segmentPolicy ?? this.segmentPolicy,
      style: style ?? this.style,
    );
  }

  /// Returns ordered renderable segments for [device].
  List<BarSegment> segmentsFor(String device) => segmentPolicy.buildSegments(
    device: device,
    values: valuesFor(device),
    style: style,
  );
}

/// Applies streamed values to the latest categorical state.
///
/// The reducer is independent of Flutter rendering and can be unit-tested or
/// driven by an external controller. A reply containing only some devices
/// leaves previously known values for other devices unchanged.
class BarChartReducer {
  /// Stable device order used for category matching.
  final List<String> deviceNames;

  /// Policy used to create renderer-ready segments.
  final BarSegmentPolicy segmentPolicy;

  /// Style used by the segment policy.
  final BarChartStyle style;

  /// Resolves the fallback color for a device without a reference.
  final Color Function(String device) colorForDevice;

  /// Semantic key used for streamed current values.
  final String currentKey;

  /// Display label used for streamed current values.
  final String currentLabel;

  BarChartReducer({
    required Iterable<String> deviceNames,
    required this.colorForDevice,
    this.segmentPolicy = const ReferenceDeltaSegmentPolicy(),
    this.style = const BarChartStyle(),
    this.currentKey = 'current',
    this.currentLabel = 'Current',
  }) : deviceNames = List.unmodifiable(deviceNames);

  BarChartModel _data = const BarChartModel(
    deviceNames: [],
    valuesByDevice: {},
  );

  /// Current renderer-neutral state.
  BarChartModel get data => _data;

  /// Captures [value] as the reference for [device].
  void setReference({required String device, required double value}) {
    _setValue(
      device: device,
      valueKey: 'reference',
      label: 'Reference',
      value: value,
      timestamp: null,
    );
  }

  /// Removes the reference for [device], or all references when omitted.
  void clearReference({String? device}) {
    final next = <String, Map<String, BarValue>>{};
    for (final name in deviceNames) {
      final values = Map<String, BarValue>.from(
        _data.valuesByDevice[name] ?? {},
      );
      if (device == null || device == name) {
        values.remove('reference');
      }
      if (values.isNotEmpty) next[name] = values;
    }
    _data = _data.copyWith(
      valuesByDevice: next,
      segmentPolicy: segmentPolicy,
      style: style,
    );
  }

  /// Replaces each device's current value found in [reply]. Unmentioned
  /// devices retain their previous values, which supports partial replies.
  void applyReply(dynamic reply) {
    final nextValues = <String, Map<String, BarValue>>{
      for (final entry in _data.valuesByDevice.entries)
        entry.key: Map<String, BarValue>.from(entry.value),
    };
    final units = Map<String, String>.from(_data.unitsByDevice);
    final errors = <String, String>{};

    for (final channel in reply.data) {
      final device = channel.name as String;
      if (!deviceNames.contains(device)) continue;

      if ((channel.status as int) < 0) {
        errors[device] = 'Channel error (${channel.status})';
        continue;
      }
      if (channel.points.isEmpty) continue;

      final point = channel.points.last;
      final value = _numericValue(point.value);
      if (value == null) continue;

      units[device] = channel.units as String;
      final deviceValues = nextValues.putIfAbsent(device, () => {});
      final previous = deviceValues[currentKey];
      deviceValues[currentKey] = BarValue(
        key: currentKey,
        label: currentLabel,
        value: value,
        color: previous?.color ?? colorForDevice(device),
        timestamp: point.t as double?,
      );
    }

    _data = BarChartModel(
      deviceNames: deviceNames,
      valuesByDevice: nextValues,
      unitsByDevice: units,
      errorsByDevice: errors,
      segmentPolicy: segmentPolicy,
      style: style,
    );
  }

  double? _numericValue(dynamic value) {
    if (value is num) return value.toDouble();
    final scalar = value as dynamic;
    try {
      final result = scalar.value;
      if (result is num) return result.toDouble();
    } catch (_) {}
    try {
      final values = scalar.values;
      if (values is List && values.isNotEmpty) {
        final last = values.last;
        if (last is List && last.length > 1 && last[1] is num) {
          return (last[1] as num).toDouble();
        }
      }
    } catch (_) {}
    return null;
  }

  void _setValue({
    required String device,
    required String valueKey,
    required String label,
    required double value,
    required double? timestamp,
  }) {
    if (!deviceNames.contains(device)) return;
    final next = <String, Map<String, BarValue>>{
      for (final entry in _data.valuesByDevice.entries)
        entry.key: Map<String, BarValue>.from(entry.value),
    };
    final values = next.putIfAbsent(device, () => {});
    values[valueKey] = BarValue(
      key: valueKey,
      label: label,
      value: value,
      color: valueKey == 'reference'
          ? const Color(0xFF9E9E9E)
          : colorForDevice(device),
      timestamp: timestamp,
    );
    _data = _data.copyWith(valuesByDevice: next);
  }
}
