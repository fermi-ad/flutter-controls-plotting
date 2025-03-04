import 'dart:math';

import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class PlotData {
  // min/max XY that is currently displayed on the plot.
  double? _minY, _maxY, _minX, _maxX;

  // Map of channel name and points.
  Map<String, List<PlotPoint>> points = {};

  bool isUseEventX = false;

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

  void findPointsLimits({double? untilXMin}) {
    double? minY, maxY, minX, maxX;

    for (var pointList in points.values) {
      (minY, maxY, minX, maxX) = _getLimitsPerPoints(
          points: pointList,
          minY: minY,
          maxY: maxY,
          minX: minX,
          maxX: maxX,
          untilXMin: untilXMin);
    }

    setLimits(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void findLimits(
      {required List<PlotChannelData> plotChannels,
      required double? confMinY,
      required double? confMaxY,
      required double? confMinX,
      required double? confMaxX,
      required double? timeDelta}) {
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

    if (timeDelta == null) {
      if (confMinX != null) {
        minX = confMinX;
      }
      if (confMaxX != null) {
        maxX = confMaxX;
      }
    } else {
      if (isUseEventX) {
        // X axis is displayed as an time relevant to event.
        minX = 0;
        maxX = timeDelta;
      } else {
        // X axis is displayed as a linear timeline.
        // Find time offset
        minX = maxX! - timeDelta;
        // Calculate y based on points displayed.
        if (confMinY == null && confMaxY == null) {
          findPointsLimits(untilXMin: minX);
          minY = _minY;
          maxY = _maxY;
        }
      }
    }

    // Override configuration
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
    double? untilXMin,
  }) {
    for (int i = points.length - 1; i >= 0; i--) {
      final point = points[i];
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

      double xPoint;
      if (isUseEventX && point.eventX != null) {
        xPoint = point.eventX!;
      } else {
        xPoint = point.x;
      }

      if (minX == null) {
        minX = xPoint;
      } else {
        minX = min(xPoint, minX);
      }
      if (maxX == null) {
        maxX = xPoint;
      } else {
        maxX = max(xPoint, maxX);
      }

      if (untilXMin != null) {
        if (minX <= untilXMin) {
          break;
        }
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
