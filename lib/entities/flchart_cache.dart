import 'dart:math';

import 'package:flutter_controls_plotting/entities/channel_metadata.dart';
import 'package:flutter_controls_plotting/entities/plotting_point.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plotting_fl_spot.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class FlchartCache {
  static const int minimumNumberOfReducedPoints = 8000;

  final Map<String, List<List<PlottingFlSpot>>> spots = {};
  final Map<String, PlottingFlSpot> tempSpot = {};
  final Map<String, List<int>> lastProcessedIndex = {};

  int? reducedPoints;
  int totalPoints = 0;

  bool _resetCache = false;
  double? _spotsMinX;
  double? _spotsMaxX;
  double? _spotsMinY;
  double? _spotsMaxY;

  // Tracks the last Y limits used for normalization per channel.
  // Allows normalizeCacheSpots to skip channels whose limits haven't changed.
  final Map<String, ({double? minY, double? maxY})> _lastNormalizedLimits = {};

  // Datalogger skip cache spots.
  double? _dataLoggerStartTime;
  double? _dataLoggerEndTime;
  bool _dLoggerApplyPredictiveReduction = false;
  final Map<String, double> _dLoggerEstimatedNumberOfPointsPerCh = {};
  double? __dLoggerEstimatedNumberOfPoints;
  int? __dLoggerPointSkipCount;

  List<PlottingFlSpot> toSpots({
    required List<PlottingPoint> points,
    required channelName,
    required int segmentIndex,
    required ChannelSetting channelSetting,
    double? minX,
    double? maxX,
    double? minY,
    double? maxY,
    bool exitForScalar = false,
    bool appendExistingArrayPoints = false,
    // Last point will have its own segment for blinking puprposes created outside of cache.
    bool skipLastPoint = false,
  }) {
    if (!_resetCache) {
      _resetCache = shouldResetCache(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
      );
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

    List<PlottingFlSpot> flSpots;
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
      // Use a direct reference — no copy needed since we mutate in place below.
      flSpots = spots[channelName]![segmentIndex];
      startIndex = lastProcessedIndex[channelName]![segmentIndex] + 1;

      // As the rolling window's left edge (minX) advances, cached spots that
      // have scrolled out of view pile up at the front of the list — causing
      // artificially dense rendering on the left.  Trim them now using a
      // binary search so the visible density stays uniform across the window.
      if (minX != null && flSpots.isNotEmpty && flSpots.first.x < minX) {
        int lo = 0, hi = flSpots.length;
        while (lo < hi) {
          final mid = (lo + hi) >> 1;
          if (flSpots[mid].x < minX) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        // Keep one point just outside the left edge as a boundary pair so the
        // line is drawn all the way to the axis edge (same role as minXPair).
        final trimTo = (lo - 1).clamp(0, flSpots.length);
        if (trimTo > 0) {
          flSpots.removeRange(0, trimTo);
        }
      }

      if (startIndex >= points.length) {
        if (appendExistingArrayPoints) {
          totalPoints += ((maxX ?? points.length - 1) - (minX ?? 0) + 1)
              .toInt();

          if (minX != null && minX > 0) {
            totalPoints += 1;
          }
          if (maxX != null && maxX < points.length - 1) {
            totalPoints += 1;
          }
        }
        return flSpots;
      }
    } else {
      flSpots = [];
    }

    PlottingPoint? minXPair;
    PlottingPoint? maxXPair;
    PlottingPoint? minYPair;
    PlottingPoint? maxYPair;

    int? minXPairIndex;
    int? maxXPairIndex;
    int? minYPairIndex;
    int? maxYPairIndex;

    List<PlottingFlSpot> newSpots = [];
    if (points.length == 1) {
      skipLastPoint = false;
    }
    final int endIndex = skipLastPoint ? points.length - 1 : points.length;

    // First pass (newest-to-oldest): find boundary pairs and collect eligible
    // point indices. Boundary pair *Index values are recorded as positions in
    // the forward-ordered newSpots list we will build in the second pass.
    // We do a single reverse scan to respect the existing early-exit logic
    // (exitForScalar, xRangeMin break), then build newSpots oldest-to-newest.
    final List<int> eligibleIndices = [];
    for (int i = endIndex - 1; i >= startIndex; i--) {
      PlottingPoint point = points[i];
      var x = point.x;
      var y = point.y;

      if (channelSetting.isLogScale) {
        if (y <= 0) {
          // For log scale, skip non-positive values.
          continue;
        }
        // Use natural logarithm (base e)
        y = log(y);
      }

      // Skip points based on the calculated skip count for data logger
      if (skipIndexCount != null && skipIndexCount > 1) {
        if (_dataLoggerEndTime == null ||
            _dataLoggerEndTime != null && x > _dataLoggerEndTime!) {
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
          maxXPair = PlottingPoint(x: x, y: y);
          maxXPairIndex = eligibleIndices.length;
        } else if ((minX != null && x < minX) &&
            (minXPair == null || minXPair.x < x)) {
          minXPair = PlottingPoint(x: x, y: y);
          minXPairIndex = eligibleIndices.length;
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
          maxYPair = PlottingPoint(x: x, y: y);
          maxYPairIndex = eligibleIndices.length;
        } else if ((minY != null && y < minY) &&
            (minYPair == null || minYPair.y < y)) {
          minYPair = PlottingPoint(x: x, y: y);
          minYPairIndex = eligibleIndices.length;
        }
        addPoint = false;
      }

      if (addPoint) {
        eligibleIndices.add(i);
      }
    }

    // Second pass: build newSpots oldest-to-newest using add() (O(1) amortized)
    // instead of insert(0,...) which was O(k²) across the loop.
    for (int i = eligibleIndices.length - 1; i >= 0; i--) {
      final point = points[eligibleIndices[i]];
      var y = point.y;
      if (channelSetting.isLogScale && y > 0) y = log(y);
      final flSpot = PlottingFlSpot(
        point.x,
        y,
      ).withNormalizedY(_normalizeY(y, channelSetting: channelSetting));
      newSpots.add(flSpot);
    }

    // Collect the indices and corresponding FlSpot objects
    final List<MapEntry<int, PlottingFlSpot>> spotsToInsert = [];

    if (minXPairIndex != null) {
      final s = PlottingFlSpot(minXPair!.x, minXPair.y).withNormalizedY(
        _normalizeY(minXPair.y, channelSetting: channelSetting),
      );
      spotsToInsert.add(MapEntry(minXPairIndex, s));
    }
    if (maxXPairIndex != null) {
      final s = PlottingFlSpot(maxXPair!.x, maxXPair.y).withNormalizedY(
        _normalizeY(maxXPair.y, channelSetting: channelSetting),
      );
      spotsToInsert.add(MapEntry(maxXPairIndex, s));
    }
    if (minYPairIndex != null) {
      final s = PlottingFlSpot(minYPair!.x, minYPair.y).withNormalizedY(
        _normalizeY(minYPair.y, channelSetting: channelSetting),
      );
      spotsToInsert.add(MapEntry(minYPairIndex, s));
    }
    if (maxYPairIndex != null) {
      final s = PlottingFlSpot(maxYPair!.x, maxYPair.y).withNormalizedY(
        _normalizeY(maxYPair.y, channelSetting: channelSetting),
      );
      spotsToInsert.add(MapEntry(maxYPairIndex, s));
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

    if (skipLastPoint && points.isNotEmpty) {
      PlottingPoint lastPoint = points[points.length - 1];
      var lastX = lastPoint.x;
      var lastY = lastPoint.y;

      if (channelSetting.isLogScale) {
        if (lastY > 0) {
          lastY = log(lastY);
        }
      }

      PlottingFlSpot? existingSpot;
      if (tempSpot.containsKey(channelName)) {
        existingSpot = tempSpot[channelName];
      }

      if (existingSpot == null ||
          existingSpot.x != lastX ||
          existingSpot.y != lastY) {
        if (existingSpot != null) {
          flSpots.add(existingSpot);
        }

        final newTempSpot = PlottingFlSpot(
          lastX,
          lastY,
        ).withNormalizedY(_normalizeY(lastY, channelSetting: channelSetting));
        tempSpot[channelName] = newTempSpot;
      }
    }

    spots[channelName]![segmentIndex] = flSpots;
    lastProcessedIndex[channelName]![segmentIndex] = points.length - 1;
    return flSpots;
  }

  void normalizeCacheSpots({required Map<String, ChannelMetadata> channels}) {
    for (var entry in spots.entries) {
      var channelName = entry.key;
      var channelSpots = entry.value;
      var channelSetting = channels[channelName]!.channelSetting;

      final currentMinY = channelSetting.displayedMinY;
      final currentMaxY = channelSetting.displayedMaxY;
      final lastLimits = _lastNormalizedLimits[channelName];

      // Skip full re-normalization if Y limits haven't changed since last frame.
      if (lastLimits != null &&
          lastLimits.minY == currentMinY &&
          lastLimits.maxY == currentMaxY) {
        continue;
      }

      // Y limits changed — re-normalize all cached spots for this channel.
      _lastNormalizedLimits[channelName] = (
        minY: currentMinY,
        maxY: currentMaxY,
      );

      for (var segmentSpots in channelSpots) {
        for (var i = 0; i < segmentSpots.length; i++) {
          segmentSpots[i] = segmentSpots[i].withNormalizedY(
            _normalizeY(
              segmentSpots[i].originalY,
              channelSetting: channelSetting,
            ),
          );
        }
      }
      if (tempSpot.containsKey(channelName)) {
        final spot = tempSpot[channelName]!;
        tempSpot[channelName] = spot.withNormalizedY(
          _normalizeY(spot.originalY, channelSetting: channelSetting),
        );
      }
    }
  }

  double _normalizeY(double y, {required ChannelSetting channelSetting}) {
    final max = channelSetting.displayedMaxY ?? 1;
    final min = channelSetting.displayedMinY ?? 0;

    if (min == max) {
      return 0;
    }

    final ySpan = max - min;
    final ret = (y - min) / ySpan;

    return ret;
  }

  bool shouldResetCache({
    double? minX,
    double? maxX,
    double? minY,
    double? maxY,
  }) {
    // A full cache reset is only needed when the visible window *contracts* or
    // *jumps* so that previously-excluded points might now be in range:
    //   - minX decreased: earlier points that were outside the left edge are
    //     now visible and must be added — cache doesn't have them.
    //   - maxX decreased: the right edge moved left (zoom/pan); cached points
    //     beyond the new maxX must be removed — easiest to just rebuild.
    //   - minY or maxY tightened inward: points outside the new Y range were
    //     previously included and must now be excluded.
    //
    // What does NOT require a reset:
    //   - maxX grew (rolling window advancing) — new points are appended
    //     incrementally by toSpots via the startIndex mechanism.
    //   - minX grew (old points scrolled off) — handled by trimFront.
    if (_spotsMinX != null && minX != null && minX < _spotsMinX!) {
      return true;
    }
    if (_spotsMaxX != null && maxX != null && maxX < _spotsMaxX!) {
      return true;
    }
    if (_spotsMinY != null && minY != null && minY < _spotsMinY!) {
      return true;
    }
    if (_spotsMaxY != null && maxY != null && maxY < _spotsMaxY!) {
      return true;
    }
    return false;
  }

  bool __isWithinBounds(double value, double? min, double? max) {
    // Check if the given value is within the specified bounds (min and max).
    return (min == null || value >= min) && (max == null || value <= max);
  }

  int? reduceSpots({
    int minimumPointsNeeded = minimumNumberOfReducedPoints,
    int maxiumumPointsDisplayed = 10000,
    int minimumPointsPerSegment = 50,
    Map<String, List<int>> displayedSegments = const {},
  }) {
    int numberOfPoints = 0;
    for (var entry in spots.entries) {
      var channelName = entry.key;
      var channelSpots = entry.value;
      var segmentsToDisplay = displayedSegments[channelName] ?? [];
      for (
        var segmentIndex = 0;
        segmentIndex < channelSpots.length;
        segmentIndex++
      ) {
        if (segmentsToDisplay.isNotEmpty &&
            !segmentsToDisplay.contains(segmentIndex)) {
          continue;
        }
        var segmentSpots = channelSpots[segmentIndex];
        numberOfPoints += segmentSpots.length;
      }
    }

    if (numberOfPoints > maxiumumPointsDisplayed) {
      if (reducedPoints != null) {
        // Cache was already reduced and new data has grown it back above the
        // threshold. Re-reduce in place without triggering a full cache reset.
        // The old code set _resetCache=true here which caused a full rebuild
        // of all raw points on every frame — that was the root cause of jank.
        reducedPoints = null;
      }
      reducedPoints ??= 0;
      for (var entry in spots.entries) {
        var channelName = entry.key;
        var channelSpots = entry.value;
        var segmentsToDisplay = displayedSegments[channelName] ?? [];
        for (
          var segmentIndex = 0;
          segmentIndex < channelSpots.length;
          segmentIndex++
        ) {
          if (segmentsToDisplay.isNotEmpty &&
              !segmentsToDisplay.contains(segmentIndex)) {
            continue;
          }
          var spots = channelSpots[segmentIndex];
          var spotsPercentage = spots.length / numberOfPoints;
          var maxSpots = (minimumPointsNeeded * spotsPercentage).ceil();
          // The reduction should never be less than specified points per segment.
          maxSpots = max(minimumPointsPerSegment, maxSpots);
          __reduceSpots(spots: spots, maxPoints: maxSpots);
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

  List<PlottingFlSpot> __reduceSpots({
    required List<PlottingFlSpot> spots,
    required int maxPoints,
  }) {
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

  void prepareDataLoggerAcquisition({
    double? startTime,
    double? endTime,
    bool applyPredictiveReduction = true,
  }) {
    clearDataLogger();

    _dLoggerApplyPredictiveReduction = applyPredictiveReduction;

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
    if (!isDataLogger) {
      return null;
    }
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
      __dLoggerPointSkipCount = (estimatedPoints / minimumNumberOfReducedPoints)
          .ceil();
    }

    return __dLoggerPointSkipCount;
  }

  void estimateDataLoggerPoints({
    required String channelName,
    required List<PlottingPoint> firstSample,
  }) {
    if (!isDataLogger) {
      return;
    }

    if (!_dLoggerApplyPredictiveReduction) {
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

  /// Removes [pointsRemoved] raw points from the front of segment [segmentIndex]
  /// for [channelName], trimming the corresponding cached FlSpots and adjusting
  /// [lastProcessedIndex] so incremental cache builds remain correct.
  ///
  /// If the segment is fully consumed or not yet cached, it is dropped entirely.
  /// Entire-segment removals ([segmentsRemoved] > 0) are handled by removing
  /// those segments from both [spots] and [lastProcessedIndex].
  void trimFront({
    required String channelName,
    required int segmentsRemoved,
    required int pointsRemovedFromNextSegment,
    required int remainingPointsInNextSegment,
  }) {
    if (!spots.containsKey(channelName)) return;

    final channelSpots = spots[channelName]!;
    final channelIdx = lastProcessedIndex[channelName]!;

    // Drop fully-removed segments from the front.
    if (segmentsRemoved > 0) {
      final toDrop = segmentsRemoved.clamp(0, channelSpots.length);
      channelSpots.removeRange(0, toDrop);
      channelIdx.removeRange(0, toDrop);
    }

    // Trim points from the front of the next segment (now index 0).
    if (pointsRemovedFromNextSegment > 0 && channelSpots.isNotEmpty) {
      final segSpots = channelSpots[0];
      // The ratio of spots-per-raw-point may not be 1:1 after reduction,
      // so compute the proportion of spots to drop.
      final totalRaw =
          pointsRemovedFromNextSegment + remainingPointsInNextSegment;
      if (totalRaw > 0 && segSpots.isNotEmpty) {
        final spotsToDrop =
            ((pointsRemovedFromNextSegment / totalRaw) * segSpots.length)
                .floor();
        if (spotsToDrop >= segSpots.length) {
          segSpots.clear();
          channelIdx[0] = -1;
        } else if (spotsToDrop > 0) {
          segSpots.removeRange(0, spotsToDrop);
          // Shift lastProcessedIndex down by the number of raw points removed.
          channelIdx[0] = (channelIdx[0] - pointsRemovedFromNextSegment).clamp(
            -1,
            1 << 30,
          );
        }
      }
    }

    // Recount totalPoints from what actually remains in the cache.
    totalPoints = 0;
    for (final segs in spots.values) {
      for (final seg in segs) {
        totalPoints += seg.length;
      }
    }
    reducedPoints = null;
    _resetCache = false;
  }

  void clearAll() {
    spots.clear();
    lastProcessedIndex.clear();
    _lastNormalizedLimits.clear();

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
    _dLoggerApplyPredictiveReduction = false;
    reducedPoints = null;
  }

  // Clears cached spots for a specific channel.
  void clearChannel(String channelName) {
    spots.remove(channelName);
    lastProcessedIndex.remove(channelName);
    tempSpot.remove(channelName);
    _lastNormalizedLimits.remove(channelName);
  }
}
