import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class PlotMetadata with ChangeNotifier {
  double? _latestRequestEpochTime;
  double? _latestDataEpochTime;

  PlotMetadata();

  String get latestRequestEpochTimeText {
    if (lastestRequestEpochTime != null) {
      return parseDaqTimeAsString(lastestRequestEpochTime!);
    }

    return "Unknown";
  }

  String get latestDataEpochTimeText {
    if (latestDataEpochTime != null) {
      return parseDaqTimeAsString(latestDataEpochTime!);
    }

    return "Unknown";
  }

  double? get lastestRequestEpochTime => _latestRequestEpochTime;
  double? get latestDataEpochTime => _latestDataEpochTime;

  set latestRequestEpochTime(double? lastestRequestEpochTime) {
    _latestRequestEpochTime = lastestRequestEpochTime;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  set latestDataEpochTime(double? latestDataEpochTime) {
    _latestDataEpochTime = latestDataEpochTime;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  void cleanUp() {
    _latestDataEpochTime = null;
    _latestRequestEpochTime = null;
  }
}
