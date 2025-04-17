import 'dart:math';

import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/entities/plot_metadata.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

// PlotPoint consists of 3 doubles each are 8 bytes.
const int _plotPointsByteSize = 3 * 8;
// Purge size of 5MB
const int _defaultPurgeDataSize = 5 * 1024 * 1024;

class PlotData {
  // min/max XY that is currently displayed on the plot.
  double? _minY, _maxY, _minX, _maxX;

  double? cursorX, cursorY;

  // Map of channel name and points split into segments.
  Map<String, List<List<PlotPoint>>> points = {};

  PlotMetadata plotMetadata = PlotMetadata();

  bool scalarEventMode = false;

  int? _maxDataBytes;

  late int purgeDataSize;

  PlotData({int? maxDataBytes, int? purgeSize}) : _maxDataBytes = maxDataBytes {
    if (purgeSize == null) {
      purgeDataSize = _defaultPurgeDataSize;
    } else {
      purgeDataSize = purgeSize;
    }
  }

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

  int? get maxDataBytes => _maxDataBytes;

  set maxDataBytes(int? maxBytes) {
    _maxDataBytes = maxBytes;
    _purgePointsOverData();
  }

  void processPlotReplyMetadata({required PlotReply plotReply}) {
    // Remove data assumption when it becomes required part of API
    double? requestTime = plotReply.requestTime;
    if (plotMetadata.latestDataEpochTime != null &&
        plotMetadata.latestDataEpochTime! >= requestTime) {
      return;
    }

    plotMetadata.latestRequestEpochTime = requestTime;
  }

  void filterPoints(
      {required bool isTimedScalarData,
      required bool isPersistent,
      required List<PlotChannelData> plotChannels}) {
    if (!isTimedScalarData && !isPersistent) {
      points.clear();
      plotMetadata.plotDataBytes = 0;
    }
    for (final plotChannel in plotChannels) {
      if (!channelHasErrorOrNoPoints(plotChannel)) {
        var newPoints = plotChannel.points;

        if (points.containsKey(plotChannel.name)) {
          var segments = points[plotChannel.name]!;
          var pointsList = segments.last;

          if (scalarEventMode) {
            for (var point in newPoints) {
              // Check if a new event should be started.
              var lastX = pointsList.last.x;
              var newX = point.x;

              if (newX < lastX) {
                if (!isPersistent) {
                  // Clear all events.
                  _clearSegments(segments);
                }
                // Reset point limits based on the current data since data is being removed.
                findPointsLimits();
                // New event
                segments.add([]);
                // Reload pointsList
                pointsList = segments.last;
              }
              var lastIndex = pointsList.length;
              pointsList.insert(lastIndex, point);
            }
          } else {
            var lastIndex = pointsList.length;
            pointsList.insertAll(lastIndex, newPoints);
          }
        } else {
          points[plotChannel.name] = [];
          points[plotChannel.name]!.add(List.from(newPoints));
        }
        // Add bytes from the points added.
        _appendPointsCalculation(newPoints);
        _purgePointsOverData();

        // Update last response time.
        double? t = plotChannel.points.last.t;

        if (t != null &&
            (plotMetadata.latestDataEpochTime == null ||
                plotMetadata.latestDataEpochTime! < t)) {
          plotMetadata.latestDataEpochTime = t;
        }
      }
    }
  }

  void _appendPointsCalculation(List<PlotPoint> points) {
    plotMetadata.plotDataBytes += points.length * _plotPointsByteSize;
  }

  void _removePointsCalculation(List<PlotPoint> points) {
    plotMetadata.plotDataBytes -= points.length * _plotPointsByteSize;
  }

  void _clearSegments(List<List<PlotPoint>> segments) {
    for (var pointsList in segments) {
      _removePointsCalculation(pointsList);
    }
    segments.clear();
  }

  int _calculateSizeOfAllSegments(List<List<PlotPoint>> segments) {
    int dataSize = 0;

    for (var pointList in segments) {
      dataSize += pointList.length * _plotPointsByteSize;
    }

    return dataSize;
  }

  void _recalculateDataForAllPoints() {
    plotMetadata.plotDataBytes = 0;

    for (var segments in points.values) {
      for (var pointList in segments) {
        _appendPointsCalculation(pointList);
      }
    }
  }

  void _purgePointsOverData() {
    if (maxDataBytes == null) {
      //Nothing to do.
      return;
    }
    if (plotMetadata.plotDataBytes < maxDataBytes!) {
      // Not enough data to purge.
      return;
    }

    // Calculate number of points to purge.
    var plotDataBytes = plotMetadata.plotDataBytes;
    var bytesOverage = plotDataBytes - maxDataBytes!;
    var bytesToPurge = bytesOverage + purgeDataSize;

    int pointsToPurge = (bytesToPurge / _plotPointsByteSize).ceil();

    for (var segments in points.values) {
      double percentage = _calculateSizeOfAllSegments(segments) / plotDataBytes;
      int pointsToPurgePerCh = (pointsToPurge * percentage).ceil();
      int segmentsToRemove = 0;
      for (var segment in segments) {
        if (segment.length > pointsToPurgePerCh) {
          // Remove all necessary points from this segemnt.
          segment.removeRange(0, pointsToPurgePerCh);
          break;
        } else {
          // Add segment for removal
          segmentsToRemove += 1;
          pointsToPurgePerCh -= segment.length;
        }
        if (segmentsToRemove > 0) {
          segments.removeRange(0, segmentsToRemove);
        }
      }
    }

    _recalculateDataForAllPoints();
  }

  void findPointsLimits({double? untilXMin}) {
    double? minY, maxY, minX, maxX;

    for (var segments in points.values) {
      for (var pointList in segments) {
        (minY, maxY, minX, maxX) = _getLimitsPerPoints(
            points: pointList,
            minY: minY,
            maxY: maxY,
            minX: minX,
            maxX: maxX,
            untilXMin: untilXMin);
      }
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
      if (channelHasErrorOrNoPoints(plotChannel)) {
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
      if (scalarEventMode) {
        // X axis is displayed as an time relevant to event.
        minX = 0;
        maxX = timeDelta;
      } else {
        // X axis is displayed as a linear timeline.
        // Find time offset
        // confX is set when panning.
        if (confMaxX != null) {
          maxX = confMaxX;
        }
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
      double yPoint = point.y;

      if (minY == null) {
        minY = yPoint;
      } else {
        minY = min(yPoint, minY);
      }
      if (maxY == null) {
        maxY = yPoint;
      } else {
        maxY = max(yPoint, maxY);
      }

      double xPoint = point.x;

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

  void persistenceCleanUp({
    required bool isTimedScalarData,
    required bool isPersistent,
  }) {
    if (isTimedScalarData) {
      // Scalar Reading Mode
      if (!isPersistent) {
        for (var entry in points.entries) {
          List<List<PlotPoint>> segments = entry.value;
          if (segments.isNotEmpty) {
            segments.removeRange(0, segments.length - 1);
          }
        }
        // Potential clean up for scalar data. Recaluclate limits for all points.
        findPointsLimits();
        _recalculateDataForAllPoints();
      }
    }
  }

  void cleanUpPoints(
      {Iterable<String> keepChannelList = const Iterable.empty()}) {
    List<String> garbageChannels = [];
    for (var channelName in points.keys) {
      if (!keepChannelList.contains(channelName)) {
        garbageChannels.add(channelName);
      }
    }

    for (var garbageChannel in garbageChannels) {
      points.remove(garbageChannel);
    }

    if (garbageChannels.isNotEmpty) {
      // Displayed channels changed.
      plotMetadata.cleanUp();
      _recalculateDataForAllPoints();
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
