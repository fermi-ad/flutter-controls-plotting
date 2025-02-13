import 'dart:math';

import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class PlotData {
  // min/max XY that is currently displayed on the plot.
  double? _minY, _maxY, _minX, _maxX;

  // Map of channel name and points.
  Map<String, List<PlotPoint>> points = {};

  PlotData();

  double? get minX {
    if (points.isEmpty) {
      return 0;
    }
    return _minX;
  }

  double? get maxX {
    if (points.isEmpty) {
      return 3.0;
    }
    return _maxX;
  }

  double? get minY {
    if (points.isEmpty) {
      return 0;
    }
    return _minY;
  }

  double? get maxY {
    if (points.isEmpty) {
      return 3.0;
    }
    return _maxY;
  }

  void filterPoints(
      {required bool isTimedScalarData,
      required List<PlotChannelData> plotChannels}) {
    if (!isTimedScalarData) {
      points.clear();
    }
    for (final plotChannel in plotChannels) {
      if (!channelHasError(plotChannel)) {
        if (points.containsKey(plotChannel.name)) {
          var pointsList = points[plotChannel.name]!;
          var lastIndex = pointsList.length;
          pointsList.insertAll(lastIndex, plotChannel.points);
        } else {
          points[plotChannel.name] = plotChannel.points;
        }
      }
    }
  }

  void findPointsLimits() {
    double? minY, maxY, minX, maxX;

    for (var pointList in points.values) {
      (minY, maxY, minX, maxX) = _getLimitsPerPoints(
          points: pointList, minY: minY, maxY: maxY, minX: minX, maxX: maxX);
    }

    setLimits(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void findLimits({
    required List<PlotChannelData> plotChannels,
    required double? confMinY,
    required double? confMaxY,
    required double? confMinX,
    required double? confMaxX,
  }) {
    double? minY = _minY;
    double? maxY = _maxY;
    double? minX = _minX;
    double? maxX = _maxX;

    for (var plotChannel in plotChannels) {
      if (channelHasError(plotChannel)) {
        continue;
      }
      final points = plotChannel.points;
      (minY, maxY, minX, maxX) = _getLimitsPerPoints(
          points: points, minY: minY, maxY: maxY, minX: minX, maxX: maxX);
    }

    // Override configuration
    if (confMinX != null) {
      minX = confMinX;
    }
    if (confMaxX != null) {
      maxX = confMaxX;
    }

    if (confMinY != null) {
      minY = confMinY;
    }
    if (confMaxY != null) {
      maxY = confMaxY;
    }

    setLimits(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  (double?, double?, double?, double?) _getLimitsPerPoints({
    required List<PlotPoint> points,
    required double? minY,
    required double? maxY,
    required double? minX,
    required double? maxX,
  }) {
    for (final point in points) {
      if (minY == null) {
        minY = point.y;
      } else {
        minY = min(point.y, minY);
      }
      if (maxY == null) {
        maxY = point.y;
      } else {
        maxY = max(point.y, maxY);
      }
      if (minX == null) {
        minX = point.x;
      } else {
        minX = min(point.x, minX);
      }
      if (maxX == null) {
        maxX = point.x;
      } else {
        maxX = max(point.x, maxX);
      }
    }

    return (minY, maxY, minX, maxX);
  }

  void cleanUpPoints(Iterable<String> channelList) {
    List<String> garbageChannels = [];
    for (var channelName in points.keys) {
      if (!channelList.contains(channelName)) {
        garbageChannels.add(channelName);
      }
    }

    for (var garbageChannel in garbageChannels) {
      points.remove(garbageChannel);
    }
  }

  void resetMinMaxXY() {
    _minX = null;
    _maxX = null;
    _minY = null;
    _maxY = null;
  }

  void setLimits({double? minY, double? maxY, double? minX, double? maxX}) {
    _minY = minY;
    _maxY = maxY;
    _minX = minX;
    _maxX = maxX;
  }
}
