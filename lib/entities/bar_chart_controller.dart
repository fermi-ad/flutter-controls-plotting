import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'dart:ui';

import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';

/// Controls the segments displayed for a categorical device bar chart.
///
/// Inject this controller into a bar chart widget when another widget needs to
/// add/update/remove segments, or observe the latest chart model. This
/// library only stores and replays whatever segments the caller supplies —
/// it has no notion of "reference" or "comparison" values; callers that want
/// that behavior can supply named segments (e.g. `reading`, `setpoint`)
/// themselves and style/label them accordingly.
///
/// Device order, style, and color resolution are fixed at construction. The
/// caller owns this controller and must dispose it when no longer needed;
/// a widget using an external controller does not dispose it.
///
/// Each successful mutation notifies listeners synchronously, even when the
/// model's values are unchanged or an unknown device is ignored. A mutation
/// that throws during stacked validation leaves [data] unchanged and does not
/// notify listeners.
class BarChartController extends ChangeNotifier {
  final BarChartReducer _reducer;

  /// Creates an empty chart with a fixed device order and presentation style.
  ///
  /// Use distinct [deviceNames] matching the names in acquired replies.
  /// [colorForDevice] supplies colors when a mutation does not specify one;
  /// otherwise [BarChartStyle.defaultColor] is used.
  BarChartController({
    required Iterable<String> deviceNames,
    Color Function(String device)? colorForDevice,
    BarChartStyle style = const BarChartStyle(),
  }) : _reducer = BarChartReducer(
         deviceNames: deviceNames,
         colorForDevice: colorForDevice,
         style: style,
       );

  /// The latest immutable, renderer-neutral chart snapshot.
  ///
  /// Previously obtained snapshots remain unchanged after later mutations.
  BarChartModel get data => _reducer.data;

  /// Applies a streamed plot reply, updating one named segment (identified
  /// by [segmentKey]) per device found in the reply. Devices omitted from a
  /// partial reply retain their previously known segments.
  ///
  /// Uses the last point of each recognized channel, accepting scalar values
  /// or the final sample of a non-empty time series. Unknown channels, empty
  /// points, and unsupported values are ignored. Negative channel statuses
  /// preserve existing segments and are recorded as channel errors.
  ///
  /// Updating a segment preserves its position and color; a new key is
  /// appended. Units and timestamps come from the accepted point's channel
  /// and point respectively. Channel errors are replaced by those in this
  /// reply, rather than retained across partial replies.
  ///
  /// In stacked layout, explicit ranges keep their fixed bounds and are not
  /// rebased when a streamed contribution changes. Invalid resulting intervals
  /// throw [ArgumentError] and reject the entire reply, including other devices'
  /// updates and metadata, without changing [data] or notifying listeners.
  void applyReply(
    PlotReply reply, {
    String segmentKey = 'value',
    String segmentLabel = 'Value',
  }) {
    _reducer.applyReply(
      reply,
      segmentKey: segmentKey,
      segmentLabel: segmentLabel,
    );
    notifyListeners();
  }

  /// Sets (adds or replaces) a named segment for [device]. Use this for any
  /// segment that isn't driven by the streamed reply — for example a
  /// setpoint, limit, or a manually captured comparison value.
  ///
  /// Existing keys retain their insertion position; new keys are appended.
  /// Unknown devices are ignored. An omitted [color] uses the device resolver
  /// or style default, not the segment's previous color. Replacing a streamed
  /// segment this way removes its source timestamp.
  ///
  /// In stacked layout, [value] is added on its signed side of zero. Invalid
  /// resulting stacks throw [ArgumentError] without changing [data].
  void setSegment({
    required String device,
    required String key,
    required String label,
    required double value,
    Color? color,
  }) {
    _reducer.setSegment(
      device: device,
      key: key,
      label: label,
      value: value,
      color: color,
    );
    notifyListeners();
  }

  /// Sets (adds or replaces) a segment with an explicit [start] and [end].
  ///
  /// Existing keys retain their insertion position; new keys are appended.
  /// Unknown devices are ignored. An omitted [color] uses the device resolver
  /// or style default. Explicit ranges are intended for stacked rendering;
  /// the current grouped renderer uses only additive segment values.
  ///
  /// In stacked layout, the range must be contiguous with the preceding
  /// segment on the same signed side of zero. Positive ranges extend upward;
  /// negative ranges extend downward. Gaps, overlaps, ranges crossing zero,
  /// ranges reversing toward zero, and non-finite bounds throw [ArgumentError]
  /// without changing the current chart data. Bounds are fixed coordinates and
  /// are never automatically rebased; upstream edits that break contiguity are
  /// rejected. Use [setSegment] for contributions that should move with the stack.
  void setRangeSegment({
    required String device,
    required String key,
    required String label,
    required double start,
    required double end,
    Color? color,
  }) {
    _reducer.setRangeSegment(
      device: device,
      key: key,
      label: label,
      start: start,
      end: end,
      color: color,
    );
    notifyListeners();
  }

  /// Removes matching segments without clearing units or channel errors.
  ///
  /// With both [device] and [key], removes that device's named segment. With
  /// only [device], removes all its segments. With only [key], removes that
  /// key from every device. With neither, removes all segments.
  ///
  /// In stacked layout, validates all remaining stacks before publishing.
  /// Explicit ranges keep their fixed bounds and are not rebased. Removals that
  /// break contiguity throw [ArgumentError] without changing [data] on any device
  /// or notifying listeners. Remove dependent ranges first, or clear all
  /// segments on the device in one call.
  void clearSegment({String? device, String? key}) {
    _reducer.clearSegment(device: device, key: key);
    notifyListeners();
  }
}
