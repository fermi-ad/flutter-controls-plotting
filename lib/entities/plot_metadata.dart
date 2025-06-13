import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

const int _kb = 1024;
const int _mb = _kb * 1024;
const int _gb = _mb * 1024;

class PlotMetadata with ChangeNotifier {
  double? _latestRequestEpochTime;
  double? _latestDataEpochTime;
  double? _xMin;
  double? _xMax;

  int plotDataBytes = 0;
  int _numberOfPoints = 0;

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

  String get plotDataBytesText {
    if (plotDataBytes < _kb) {
      return '${plotDataBytes}B';
    } else if (plotDataBytes < _mb) {
      return '${(plotDataBytes / _kb).floor()}KB';
    } else if (plotDataBytes < _gb) {
      return '${(plotDataBytes / _mb).toStringAsFixed(1)}MB';
    } else {
      return '${(plotDataBytes / _gb).toStringAsFixed(2)}GB';
    }
  }

  double? get lastestRequestEpochTime => _latestRequestEpochTime;
  double? get latestDataEpochTime => _latestDataEpochTime;
  double? get xMin => _xMin;
  double? get xMax => _xMax;

  set latestRequestEpochTime(double? lastestRequestEpochTime) {
    _latestRequestEpochTime = lastestRequestEpochTime;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  set latestDataEpochTime(double? latestDataEpochTime) {
    _latestDataEpochTime = latestDataEpochTime;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  int get numberOfPoints => _numberOfPoints;

  set numberOfPoints(int numberOfPoints) {
    _numberOfPoints = numberOfPoints;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  set xMin(double? xMin) {
    _xMin = xMin;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  set xMax(double? xMax) {
    _xMax = xMax;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  void cleanUp() {
    _latestDataEpochTime = null;
    _latestRequestEpochTime = null;
    _xMin = null;
    _xMax = null;
  }
}
