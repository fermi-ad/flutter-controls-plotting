import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'dart:ui';

import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';

/// Controls the segments displayed for a categorical device bar chart.
///
/// Inject this controller into [BarChartWidget] when another widget needs to
/// add/update/remove segments, or observe the latest chart model. This
/// library only stores and replays whatever segments the caller supplies —
/// it has no notion of "reference" or "comparison" values; callers that want
/// that behavior can supply named segments (e.g. `reading`, `setpoint`)
/// themselves and style/label them accordingly.
class BarChartController extends ChangeNotifier {
  final BarChartReducer _reducer;

  BarChartController({
    required Iterable<String> deviceNames,
    Color Function(String device)? colorForDevice,
    BarChartStyle style = const BarChartStyle(),
  }) : _reducer = BarChartReducer(
         deviceNames: deviceNames,
         colorForDevice: colorForDevice,
         style: style,
       );

  /// The latest renderer-neutral chart state.
  BarChartModel get data => _reducer.data;

  /// Applies a streamed plot reply, updating one named segment (identified
  /// by [segmentKey]) per device found in the reply. Devices omitted from a
  /// partial reply retain their previously known segments.
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

  /// Removes the segment identified by [key] for [device]. When [key] is
  /// omitted, removes all segments for [device]. When [device] is also
  /// omitted, clears segments for every device.
  void clearSegment({String? device, String? key}) {
    _reducer.clearSegment(device: device, key: key);
    notifyListeners();
  }
}
