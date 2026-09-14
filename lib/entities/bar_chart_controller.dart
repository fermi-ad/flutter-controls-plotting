import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'dart:ui';

import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment_policy.dart';

/// Controls current/reference state for a categorical device bar chart.
///
/// Inject this controller into [BarChartWidget] when another widget
/// needs to capture or clear references, or observe the latest chart model.
class BarChartController extends ChangeNotifier {
  final BarChartReducer _reducer;

  BarChartController({
    required Iterable<String> deviceNames,
    Color Function(String device)? colorForDevice,
    BarSegmentPolicy segmentPolicy = const ReferenceDeltaSegmentPolicy(),
    BarChartStyle style = const BarChartStyle(),
  }) : _reducer = BarChartReducer(
         deviceNames: deviceNames,
         colorForDevice: colorForDevice ?? ((_) => const Color(0xFF2196F3)),
         segmentPolicy: segmentPolicy,
         style: style,
       );

  /// The latest renderer-neutral chart state.
  BarChartModel get data => _reducer.data;

  /// Applies a streamed plot reply and notifies listeners.
  void applyReply(dynamic reply) {
    _reducer.applyReply(reply);
    notifyListeners();
  }

  /// Stores [value] as the comparison baseline for [device].
  void setReference({required String device, required double value}) {
    _reducer.setReference(device: device, value: value);
    notifyListeners();
  }

  /// Removes the reference for [device], or all device references when omitted.
  void clearReference({String? device}) {
    _reducer.clearReference(device: device);
    notifyListeners();
  }
}
