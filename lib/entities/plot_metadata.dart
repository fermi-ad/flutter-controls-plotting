import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

const int _kb = 1024;
const int _mb = _kb * 1024;
const int _gb = _mb * 1024;

class PlotMetadata with ChangeNotifier {
  double? _latestRequestEpochTime;
  double? _latestDataEpochTime;
  double? _xMin;
  double? _xMax;

  double? displayedArrayTime;

  int plotDataBytes = 0;
  int _numberOfPoints = 0;
  int? reducedPoints;

  bool _notifyScheduled = false;

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

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
    _scheduleNotify();
  }

  set latestDataEpochTime(double? latestDataEpochTime) {
    _latestDataEpochTime = latestDataEpochTime;
    _scheduleNotify();
  }

  int get numberOfPoints => _numberOfPoints;

  set numberOfPoints(int numberOfPoints) {
    _numberOfPoints = numberOfPoints;
    _scheduleNotify();
  }

  set xMin(double? xMin) {
    _xMin = xMin;
    _scheduleNotify();
  }

  set xMax(double? xMax) {
    _xMax = xMax;
    _scheduleNotify();
  }

  void cleanUp() {
    numberOfPoints = 0;
    reducedPoints = null;
    displayedArrayTime = null;
    _latestDataEpochTime = null;
    _latestRequestEpochTime = null;
    _xMin = null;
    _xMax = null;
  }
}
