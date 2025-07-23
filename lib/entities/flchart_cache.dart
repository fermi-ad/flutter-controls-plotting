import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class FlchartCache {
  static const int minimumNumberOfReducedPoints = 8000;

  final Map<String, List<List<FlSpot>>> spots = {};
  final Map<String, List<int>> lastProcessedIndex = {};

  int? reducedPoints;
  int totalPoints = 0;

  bool _resetCache = false;
  double? _spotsMinX;
  double? _spotsMaxX;
  double? _spotsMinY;
  double? _spotsMaxY;

  // Datalogger skip cache spots.
  double? _dataLoggerStartTime;
  double? _dataLoggerEndTime;
  final Map<String, double> _dLoggerEstimatedNumberOfPointsPerCh = {};
  double? __dLoggerEstimatedNumberOfPoints;
  int? __dLoggerPointSkipCount;

  List<FlSpot> toSpots(
      {required List<PlotPoint> points,
      required channelName,
      required int segmentIndex,
      required ChannelSetting channelSetting,
      double? minX,
      double? maxX,
      double? minY,
      double? maxY,
      double? normalizeMinY,
      double? normalizeMaxY,
      bool exitForScalar = false}) {
    if (!_resetCache) {
      _resetCache =
          shouldResetCache(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
    }

    if (_resetCache) {
      clearAll();
    }

    estimateDataLoggerPoints(channelName: channelName, firstSample: points);

    var skipIndexCount = _dLoggerPointSkipCount;

    // Update global min/max values
    _spotsMinX = minX;
    _spotsMaxX = maxX;
    _spotsMinY = minY;
    _spotsMaxY = maxY;

    List<FlSpot> flSpots;
    int startIndex = 0;

    if (!spots.containsKey(channelName)) {
      spots[channelName] = [];
      lastProcessedIndex[channelName] = [];
    }

    while (spots[channelName]!.length <= segmentIndex) {
      spots[channelName]!.add([]);
      lastProcessedIndex[channelName]!.add(-1);
    }

    if (spots[channelName]![segmentIndex].isNotEmpty) {
      flSpots = List.from(spots[channelName]![segmentIndex]);
      startIndex = lastProcessedIndex[channelName]![segmentIndex] + 1;

      if (startIndex >= points.length) {
        return flSpots;
      }
    } else {
      flSpots = [];
    }

    PlotPoint? minXPair;
    PlotPoint? maxXPair;
    PlotPoint? minYPair;
    PlotPoint? maxYPair;

    int? minXPairIndex;
    int? maxXPairIndex;
    int? minYPairIndex;
    int? maxYPairIndex;

    List<FlSpot> newSpots = [];
    for (int i = points.length - 1; i >= startIndex; i--) {
      PlotPoint point = points[i];
      var x = point.x;
      var y = point.y;

      // Skip points based on the calculated skip count for data logger
      if (skipIndexCount != null && skipIndexCount > 1) {
        if (x > _dataLoggerEndTime!) {
          // Data gathered
          clearDataLogger();
        } else if (i % skipIndexCount != 0) {
          // Ensure to reflect the skipped point in total points counter.
          totalPoints += 1;
          // Do not further process point, in datalogger acquisition.
          continue;
        } else {
          reducedPoints ??= 0;
        }
      }

      bool addPoint = true;

      if (!__isWithinBounds(x, minX, maxX)) {
        if ((maxX != null && x > maxX) &&
            (maxXPair == null || maxXPair.x > x)) {
          maxXPair = PlotPoint(x: x, y: y);
          maxXPairIndex = newSpots.length;
        } else if ((minX != null && x < minX) &&
            (minXPair == null || minXPair.x < x)) {
          minXPair = PlotPoint(x: x, y: y);
          minXPairIndex = newSpots.length;
          if (exitForScalar) {
            // The last relevant time was reached. No need to check rest of points.
            break;
          }
        }
        addPoint = false;
      }

      if (!__isWithinBounds(y, minY, maxY)) {
        if ((maxY != null && y > maxY) &&
            (maxYPair == null || maxYPair.y > y)) {
          maxYPair = PlotPoint(x: x, y: y);
          maxYPairIndex = newSpots.length;
        } else if ((minY != null && y < minY) &&
            (minYPair == null || minYPair.y < y)) {
          minYPair = PlotPoint(x: x, y: y);
          minYPairIndex = newSpots.length;
        }
        addPoint = false;
      }

      if (addPoint) {
        FlSpot flSpot = FlSpot(
            x,
            _normalizeY(y,
                channelName: channelName,
                channelSetting: channelSetting,
                minY: normalizeMinY,
                maxY: normalizeMaxY));
        newSpots.insert(0, flSpot);
      }
    }

    // Collect the indices and corresponding FlSpot objects
    final List<MapEntry<int, FlSpot>> spotsToInsert = [];

    if (minXPairIndex != null) {
      spotsToInsert.add(MapEntry(
          minXPairIndex,
          FlSpot(
              minXPair!.x,
              _normalizeY(minXPair.y,
                  channelName: channelName,
                  channelSetting: channelSetting,
                  minY: normalizeMinY,
                  maxY: normalizeMaxY))));
    }
    if (maxXPairIndex != null) {
      spotsToInsert.add(MapEntry(
          maxXPairIndex,
          FlSpot(
              maxXPair!.x,
              _normalizeY(maxXPair.y,
                  channelName: channelName,
                  channelSetting: channelSetting,
                  minY: normalizeMinY,
                  maxY: normalizeMaxY))));
    }
    if (minYPairIndex != null) {
      spotsToInsert.add(MapEntry(
          minYPairIndex,
          FlSpot(
              minYPair!.x,
              _normalizeY(minYPair.y,
                  channelName: channelName,
                  channelSetting: channelSetting,
                  minY: normalizeMinY,
                  maxY: normalizeMaxY))));
    }
    if (maxYPairIndex != null) {
      spotsToInsert.add(MapEntry(
          maxYPairIndex,
          FlSpot(
              maxYPair!.x,
              _normalizeY(maxYPair.y,
                  channelName: channelName,
                  channelSetting: channelSetting,
                  minY: normalizeMinY,
                  maxY: normalizeMaxY))));
    }

    // Sort the list by indices in descending order
    spotsToInsert.sort((a, b) => b.key.compareTo(a.key));

    // Insert the FlSpot objects into flSpots in order from largest index to smallest
    var offset = newSpots.length;
    for (var entry in spotsToInsert.reversed) {
      var index = offset - entry.key;
      newSpots.insert(index, entry.value);
    }

    totalPoints += newSpots.length;

    flSpots.addAll(newSpots);

    spots[channelName]![segmentIndex] = flSpots;
    lastProcessedIndex[channelName]![segmentIndex] = points.length - 1;
    return flSpots;
  }

  double _normalizeY(
    double y, {
    required String channelName,
    required ChannelSetting channelSetting,
    required double? minY,
    required double? maxY,
  }) {
    final max = channelSetting.max ?? maxY ?? 1;
    final min = channelSetting.min ?? minY ?? 0;
    final ySpan = max - min;
    final yRatio = 1 / ySpan;
    final yOffset = min.abs() * yRatio;
    return yOffset + (y * yRatio);
  }

  bool shouldResetCache({
    double? minX,
    double? maxX,
    double? minY,
    double? maxY,
  }) {
    // Check if any of the new bounds are outside the cached bounds
    if (_spotsMinX != null && minX != null && minX < _spotsMinX!) {
      return true;
    }
    if (_spotsMaxX != null && maxX != null && maxX > _spotsMaxX!) {
      return true;
    }
    if (_spotsMinY != null && minY != null && minY < _spotsMinY!) {
      return true;
    }
    if (_spotsMaxY != null && maxY != null && maxY > _spotsMaxY!) {
      return true;
    }
    return false;
  }

  bool __isWithinBounds(double value, double? min, double? max) {
    // Check if the given value is within the specified bounds (min and max).
    return (min == null || value >= min) && (max == null || value <= max);
  }

  int? reduceSpots(
      {int minimumPointsNeeded = minimumNumberOfReducedPoints,
      int maxiumumPointsDisplayed = 10000}) {
    int numberOfPoints = 0;
    for (var channelSpots in spots.values) {
      for (var segmentSpots in channelSpots) {
        numberOfPoints += segmentSpots.length;
      }
    }

    if (numberOfPoints > maxiumumPointsDisplayed) {
      if (reducedPoints != null) {
        // Already reduced, will reduce on next itteration.
        reducedPoints = numberOfPoints;
        _resetCache = true;
        return reducedPoints;
      }
      reducedPoints ??= 0;
      for (var channelSpots in spots.values) {
        for (var spots in channelSpots) {
          var spotsPercentage = spots.length / numberOfPoints;
          var maxSpots = minimumPointsNeeded * spotsPercentage;
          __reduceSpots(spots: spots, maxPoints: maxSpots.ceil());
          reducedPoints = reducedPoints! + spots.length;
        }
      }
    } else {
      if (totalPoints > numberOfPoints) {
        reducedPoints = numberOfPoints;
      } else {
        reducedPoints = null;
      }
    }

    return reducedPoints;
  }

  List<FlSpot> __reduceSpots(
      {required List<FlSpot> spots, required int maxPoints}) {
    if (spots.length <= maxPoints) {
      return spots;
    }

    double step = (spots.length - 1) / (maxPoints - 1).toDouble();

    for (int i = 0; i < maxPoints; i++) {
      int index = (i * step).round();
      spots[i] = spots[index];
    }
    spots.removeRange(maxPoints, spots.length);

    return spots;
  }

  void prepareDataLoggerAcquisition({double? startTime, double? endTime}) {
    clearDataLogger();

    if (startTime == null) {
      return;
    }

    if (startTime > getCurrentAcsysEpochTime()) {
      // No need since it is in the future.
      return;
    }

    _dataLoggerStartTime = startTime;
    if (endTime != null) {
      if (endTime > getCurrentAcsysEpochTime()) {
        endTime = getCurrentAcsysEpochTime();
      }
      _dataLoggerEndTime = endTime;
    } else {
      _dataLoggerEndTime = getCurrentAcsysEpochTime();
    }
  }

  bool get isDataLogger => _dataLoggerStartTime != null;

  double? get _dLoggerEstimatedNumberOfPoints {
    if (__dLoggerEstimatedNumberOfPoints != null) {
      return __dLoggerEstimatedNumberOfPoints;
    }

    if (_dLoggerEstimatedNumberOfPointsPerCh.isEmpty) {
      return null;
    }

    double total = 0;
    for (var points in _dLoggerEstimatedNumberOfPointsPerCh.values) {
      total += points;
    }

    __dLoggerEstimatedNumberOfPoints = total;
    return __dLoggerEstimatedNumberOfPoints;
  }

  set _dLoggerEstimatedNumberOfPoints(double? value) {
    if (value == null) {
      __dLoggerPointSkipCount = null;
    }
    __dLoggerEstimatedNumberOfPoints = value;
  }

  int? get _dLoggerPointSkipCount {
    if (__dLoggerPointSkipCount != null) {
      return __dLoggerPointSkipCount;
    }

    final estimatedPoints = _dLoggerEstimatedNumberOfPoints;
    if (estimatedPoints == null) {
      return null;
    }

    if (estimatedPoints <= minimumNumberOfReducedPoints) {
      __dLoggerPointSkipCount = 1;
    } else {
      __dLoggerPointSkipCount =
          (estimatedPoints / minimumNumberOfReducedPoints).ceil();
    }

    return __dLoggerPointSkipCount;
  }

  void estimateDataLoggerPoints({
    required String channelName,
    required List<PlotPoint> firstSample,
  }) {
    if (!isDataLogger) {
      return;
    }

    if (_dLoggerEstimatedNumberOfPointsPerCh.containsKey(channelName)) {
      return;
    }

    if (_dataLoggerStartTime == null ||
        firstSample.isEmpty ||
        firstSample.length <= 2) {
      return;
    }

    // Calculate the time span of the first sample
    double sampleStartTime = firstSample[0].x;
    double sampleEndTime = firstSample[1].x;

    double sampleTimeSpan = sampleEndTime - sampleStartTime;

    if (sampleTimeSpan <= 0) {
      return;
    }

    // Calculate total time span.
    double totalTimeSpan;
    totalTimeSpan = _dataLoggerEndTime! - _dataLoggerStartTime!;

    // Calculate points per unit time.
    double pointsPerTimeUnit = 1 / sampleTimeSpan;

    // Estimate total number of points.
    double estimatedPoints = totalTimeSpan * pointsPerTimeUnit;

    // Store the estimation for this channel.
    _dLoggerEstimatedNumberOfPointsPerCh[channelName] = estimatedPoints;

    // Reset the estimated number of points to recalculate.
    _dLoggerEstimatedNumberOfPoints = null;
  }

  void clearAll() {
    spots.clear();
    lastProcessedIndex.clear();

    _spotsMinX = null;
    _spotsMaxX = null;
    _spotsMinY = null;
    _spotsMaxY = null;

    totalPoints = 0;
    reducedPoints = null;
    _resetCache = false;

    clearDataLogger();
  }

  void clearDataLogger() {
    _dataLoggerStartTime = null;
    _dataLoggerEndTime = null;
    _dLoggerEstimatedNumberOfPointsPerCh.clear();
    _dLoggerEstimatedNumberOfPoints = null;
    reducedPoints = null;
  }
}
