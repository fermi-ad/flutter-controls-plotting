import 'package:flutter/material.dart' show Color;
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';

/// A verified interval for a segment in a stacked device bar.
class ResolvedBarSegment {
  final BarSegment segment;
  final double start;
  final double end;

  const ResolvedBarSegment({
    required this.segment,
    required this.start,
    required this.end,
  });
}

/// Renderer-neutral state for categorical device bar groups.
///
/// Device order is preserved from the device list supplied to the
/// [BarChartReducer]/[BarChartController]. Each device holds an ordered list
/// of named [BarSegment]s — for example a live reading, a setpoint, and a
/// limit — each rendered as its own independent bar next to the others.
///
/// This model does not derive segments from one another; it only stores and
/// replays whatever segments the caller supplied via [BarChartController].
class BarChartModel {
  /// Style passed to the renderer.
  final BarChartStyle style;

  /// Stable X-axis category order.
  final List<String> deviceNames;

  /// Ordered segments indexed by device name.
  final Map<String, List<BarSegment>> segmentsByDevice;

  /// Units indexed by device name.
  final Map<String, String> unitsByDevice;

  /// Latest channel errors indexed by device name.
  final Map<String, String> errorsByDevice;

  BarChartModel({
    required List<String> deviceNames,
    required Map<String, List<BarSegment>> segmentsByDevice,
    Map<String, String> unitsByDevice = const {},
    Map<String, String> errorsByDevice = const {},
    this.style = const BarChartStyle(),
  }) : deviceNames = List.unmodifiable(deviceNames),
       segmentsByDevice = Map.unmodifiable(<String, List<BarSegment>>{
         for (final entry in segmentsByDevice.entries)
           entry.key: List<BarSegment>.unmodifiable(entry.value),
       }),
       unitsByDevice = Map.unmodifiable(unitsByDevice),
       errorsByDevice = Map.unmodifiable(errorsByDevice);

  BarChartModel.empty({List<String> devices = const []})
    : deviceNames = List.unmodifiable(devices),
      segmentsByDevice = const {},
      unitsByDevice = const {},
      errorsByDevice = const {},
      style = const BarChartStyle();

  /// Returns all segments currently available for [device], in insertion
  /// order.
  List<BarSegment> segmentsFor(String device) =>
      segmentsByDevice[device] ?? const <BarSegment>[];

  /// Resolves [device]'s segments into signed contiguous intervals for stacked
  /// rendering.
  ///
  /// Additive segments begin at the preceding interval end. Explicit ranges
  /// must begin at that same end. Invalid values, reversed ranges, overlaps,
  /// and gaps throw [ArgumentError].
  List<ResolvedBarSegment> resolvedStackFor(String device) =>
      resolveStack(segmentsFor(device));

  /// Resolves [segments] into verified signed intervals beginning at zero.
  ///
  /// Positive additive values advance independently upward from zero; negative
  /// values advance independently downward from zero. Explicit ranges must be
  /// contiguous with the cursor on their own side of zero, and therefore may
  /// not cross zero.
  static List<ResolvedBarSegment> resolveStack(List<BarSegment> segments) {
    const epsilon = 1e-9;
    var positiveEnd = 0.0;
    var negativeEnd = 0.0;
    final resolved = <ResolvedBarSegment>[];

    for (final segment in segments) {
      final double start;
      final double end;
      if (segment.isAdditive) {
        final value = segment.value!;
        if (!value.isFinite) {
          throw ArgumentError.value(value, 'value', 'must be finite');
        }
        start = value < 0 ? negativeEnd : positiveEnd;
        end = start + value;
      } else if (segment.isRange) {
        start = segment.start!;
        end = segment.end!;
        if (!start.isFinite || !end.isFinite) {
          throw ArgumentError('Range bounds must be finite.');
        }
        if (start >= 0 && end >= start) {
          if ((start - positiveEnd).abs() > epsilon) {
            throw ArgumentError(
              'Positive range start ($start) must equal the preceding positive '
              'segment end ($positiveEnd).',
            );
          }
        } else if (start <= 0 && end <= start) {
          if ((start - negativeEnd).abs() > epsilon) {
            throw ArgumentError(
              'Negative range start ($start) must equal the preceding negative '
              'segment end ($negativeEnd).',
            );
          }
        } else {
          throw ArgumentError(
            'A stacked range must remain on one side of zero and extend away '
            'from zero.',
          );
        }
      } else {
        throw ArgumentError('A segment must be additive or an explicit range.');
      }
      if (!end.isFinite) {
        throw ArgumentError.value(end, 'end', 'must be finite');
      }
      resolved.add(
        ResolvedBarSegment(segment: segment, start: start, end: end),
      );
      if (end < 0) {
        negativeEnd = end;
      } else {
        positiveEnd = end;
      }
    }
    return List.unmodifiable(resolved);
  }

  /// Returns one segment for [device] by its [key], if available.
  BarSegment? segmentFor(String device, String key) {
    final segments = segmentsByDevice[device];
    if (segments == null) return null;
    for (final segment in segments) {
      if (segment.key == key) return segment;
    }
    return null;
  }

  BarChartModel copyWith({
    List<String>? deviceNames,
    Map<String, List<BarSegment>>? segmentsByDevice,
    Map<String, String>? unitsByDevice,
    Map<String, String>? errorsByDevice,
    BarChartStyle? style,
  }) {
    return BarChartModel(
      deviceNames: deviceNames ?? this.deviceNames,
      segmentsByDevice: segmentsByDevice ?? this.segmentsByDevice,
      unitsByDevice: unitsByDevice ?? this.unitsByDevice,
      errorsByDevice: errorsByDevice ?? this.errorsByDevice,
      style: style ?? this.style,
    );
  }
}

/// Applies streamed values to the latest categorical state.
///
/// The reducer is independent of Flutter rendering and can be unit-tested or
/// driven by an external controller. A reply containing only some devices
/// leaves previously known segments for other devices unchanged.
class BarChartReducer {
  /// Stable device order used for category matching.
  final List<String> deviceNames;

  /// Style carried on the produced [BarChartModel].
  final BarChartStyle style;

  /// Resolves the color for a segment on a device that doesn't specify one.
  /// Falls back to [BarChartStyle.defaultColor] when not supplied.
  final Color Function(String device)? colorForDevice;

  BarChartReducer({
    required Iterable<String> deviceNames,
    this.colorForDevice,
    this.style = const BarChartStyle(),
  }) : deviceNames = List.unmodifiable(deviceNames) {
    _data = BarChartModel(
      deviceNames: this.deviceNames,
      segmentsByDevice: const {},
      style: style,
    );
  }

  late BarChartModel _data;

  /// Current renderer-neutral state.
  BarChartModel get data => _data;

  Color _resolveColor(String device) =>
      colorForDevice?.call(device) ?? style.defaultColor;

  /// Applies a streamed plot reply, updating one named segment (identified
  /// by [segmentKey]) per device found in the reply. Devices omitted from a
  /// partial reply retain their previously known segments.
  void applyReply(
    PlotReply reply, {
    String segmentKey = 'value',
    String segmentLabel = 'Value',
  }) {
    final nextSegments = <String, List<BarSegment>>{
      for (final entry in _data.segmentsByDevice.entries)
        entry.key: List<BarSegment>.from(entry.value),
    };
    final units = Map<String, String>.from(_data.unitsByDevice);
    final errors = <String, String>{};

    for (final channel in reply.data) {
      final device = channel.name;
      if (!deviceNames.contains(device)) continue;

      if (channel.status < 0) {
        errors[device] = 'Channel error (${channel.status})';
        continue;
      }
      if (channel.points.isEmpty) continue;

      final point = channel.points.last;
      final value = _numericValue(point.value);
      if (value == null) continue;

      units[device] = channel.units;
      final segments = nextSegments.putIfAbsent(device, () => []);
      final index = segments.indexWhere((s) => s.key == segmentKey);
      final previousColor = index >= 0 ? segments[index].color : null;
      final updated = BarSegment(
        key: segmentKey,
        label: segmentLabel,
        value: value,
        color: previousColor ?? _resolveColor(device),
        timestamp: point.t,
      );
      if (index >= 0) {
        segments[index] = updated;
      } else {
        segments.add(updated);
      }
    }

    _validateStackedSegments(nextSegments);
    _data = BarChartModel(
      deviceNames: deviceNames,
      segmentsByDevice: nextSegments,
      unitsByDevice: units,
      errorsByDevice: errors,
      style: style,
    );
  }

  double? _numericValue(DeviceValue value) {
    if (value is DevScalar) return value.value;
    if (value is DevTimeSeries && value.value.isNotEmpty) {
      return value.value.last.$2;
    }
    return null;
  }

  /// Sets (adds or replaces) a named segment for [device]. Use this for any
  /// segment that isn't driven by the streamed reply, such as a setpoint,
  /// limit, or manually supplied value.
  void setSegment({
    required String device,
    required String key,
    required String label,
    required double value,
    Color? color,
  }) {
    if (!deviceNames.contains(device)) return;
    final next = <String, List<BarSegment>>{
      for (final entry in _data.segmentsByDevice.entries)
        entry.key: List<BarSegment>.from(entry.value),
    };
    final segments = next.putIfAbsent(device, () => []);
    final index = segments.indexWhere((s) => s.key == key);
    final segment = BarSegment(
      key: key,
      label: label,
      value: value,
      color: color ?? _resolveColor(device),
    );
    if (index >= 0) {
      segments[index] = segment;
    } else {
      segments.add(segment);
    }
    _validateStackedSegments(next);
    _data = _data.copyWith(segmentsByDevice: next);
  }

  /// Sets (adds or replaces) a segment with an explicit interval.
  ///
  /// When the chart uses [BarChartLayout.stacked], [start] must be contiguous
  /// with the preceding segment's resolved end.
  void setRangeSegment({
    required String device,
    required String key,
    required String label,
    required double start,
    required double end,
    Color? color,
  }) {
    if (!deviceNames.contains(device)) return;
    final next = <String, List<BarSegment>>{
      for (final entry in _data.segmentsByDevice.entries)
        entry.key: List<BarSegment>.from(entry.value),
    };
    final segments = next.putIfAbsent(device, () => []);
    final index = segments.indexWhere((segment) => segment.key == key);
    final segment = BarSegment.range(
      key: key,
      label: label,
      start: start,
      end: end,
      color: color ?? _resolveColor(device),
    );
    if (index >= 0) {
      segments[index] = segment;
    } else {
      segments.add(segment);
    }
    _validateStackedSegments(next);
    _data = _data.copyWith(segmentsByDevice: next);
  }

  void _validateStackedSegments(
    Map<String, List<BarSegment>> segmentsByDevice,
  ) {
    if (style.layout != BarChartLayout.stacked) return;
    for (final segments in segmentsByDevice.values) {
      BarChartModel.resolveStack(segments);
    }
  }

  /// Removes the segment identified by [key] for [device]. When [key] is
  /// omitted, removes all segments for [device]. When [device] is also
  /// omitted, clears segments for every device.
  void clearSegment({String? device, String? key}) {
    final next = <String, List<BarSegment>>{
      for (final entry in _data.segmentsByDevice.entries)
        entry.key: List<BarSegment>.from(entry.value),
    };
    for (final name in deviceNames) {
      if (device != null && device != name) continue;
      final segments = next[name];
      if (segments == null) continue;
      if (key == null) {
        next.remove(name);
      } else {
        segments.removeWhere((s) => s.key == key);
        if (segments.isEmpty) next.remove(name);
      }
    }
    _data = _data.copyWith(segmentsByDevice: next);
  }
}
