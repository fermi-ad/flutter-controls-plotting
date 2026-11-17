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
  final Map<String, Map<int, int>> _arrayPointCounts = {};
  int? _frameSpotBudget;

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

  void beginFrame({
    required int spotBudget,
    required bool fixedXWindow,
    double? minX,
    double? maxX,
  }) {
    if ((_frameSpotBudget != null && spotBudget > _frameSpotBudget!) ||
        (fixedXWindow && (_spotsMinX != minX || _spotsMaxX != maxX))) {
      clearAll(clearDataLoggerState: false);
    }
    _frameSpotBudget = spotBudget;
  }

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
    int spotBudget = 10000,
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
      clearAll(clearDataLoggerState: false);
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
          totalPoints += _arrayPointCounts[channelName]?[segmentIndex] ?? 0;
        }
        _sampleInPlace(flSpots, spotBudget);
        return List.of(flSpots);
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
    var eligibleCount = 0;
    var sampleStride = 1;
    int? lastEligibleIndex;
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
          maxXPairIndex = i;
        } else if ((minX != null && x < minX) &&
            (minXPair == null || minXPair.x < x)) {
          minXPair = PlottingPoint(x: x, y: y);
          minXPairIndex = i;
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
          maxYPairIndex = i;
        } else if ((minY != null && y < minY) &&
            (minYPair == null || minYPair.y < y)) {
          minYPair = PlottingPoint(x: x, y: y);
          minYPairIndex = i;
        }
        addPoint = false;
      }

      if (addPoint) {
        if (eligibleCount % sampleStride == 0) eligibleIndices.add(i);
        eligibleCount++;
        lastEligibleIndex = i;
        if (eligibleIndices.length > max(2, spotBudget) * 2) {
          final kept = (eligibleIndices.length + 1) ~/ 2;
          for (var index = 1; index < kept; index++) {
            eligibleIndices[index] = eligibleIndices[index * 2];
          }
          eligibleIndices.removeRange(kept, eligibleIndices.length);
          sampleStride *= 2;
        }
      }
    }

    if (lastEligibleIndex != null &&
        eligibleIndices.last != lastEligibleIndex) {
      eligibleIndices.add(lastEligibleIndex);
    }
    final boundaryCount = [
      minXPairIndex,
      maxXPairIndex,
      minYPairIndex,
      maxYPairIndex,
    ].whereType<int>().length;
    final rawSpotCount = eligibleCount + boundaryCount;
    final dataBudget = max(0, spotBudget - boundaryCount);
    _sampleInPlace(eligibleIndices, dataBudget);

    // Build only the points the chart can render, in oldest-to-newest order.
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
    final offset = newSpots.length;
    for (var entry in spotsToInsert) {
      final preceding = eligibleIndices.indexWhere(
        (index) => index <= entry.key,
      );
      final index = preceding == -1 ? 0 : offset - preceding;
      newSpots.insert(index, entry.value);
    }

    totalPoints += rawSpotCount;
    if (appendExistingArrayPoints) {
      (_arrayPointCounts[channelName] ??= {})[segmentIndex] = rawSpotCount;
    }

    // If the new batch of spots begins at or before the last cached spot's x,
    // the source data has refreshed (e.g. array-as-timeseries delivering a full
    // new waveform).  Discard the stale cache so we don't accumulate every
    // historical waveform snapshot in the spot list.
    if (flSpots.isNotEmpty &&
        newSpots.isNotEmpty &&
        newSpots.first.x <= flSpots.last.x) {
      flSpots.clear();
    }

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
    _sampleInPlace(flSpots, spotBudget);
    return List.of(flSpots);
  }

  static void _sampleInPlace<T>(List<T> values, int budget) {
    if (values.length <= budget) return;
    if (budget == 0) {
      values.clear();
      return;
    }
    if (budget == 1) {
      values[0] = values.last;
    } else {
      final last = values.length - 1;
      for (var i = 1; i < budget; i++) {
        values[i] = values[(i * last) ~/ (budget - 1)];
      }
    }
    values.removeRange(budget, values.length);
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

  /// Apply a global budget to existing cached spots. The chart normally
  /// allocates per-segment budgets before populating this cache.
  int? reduceSpots({
    int minimumPointsNeeded = minimumNumberOfReducedPoints,
    int maxiumumPointsDisplayed = 10000,
    int minimumPointsPerSegment = 50,
    Map<String, List<int>> displayedSegments = const {},
  }) {
    final selected = [
      for (final entry in spots.entries)
        for (final (index, segment) in entry.value.indexed)
          if (displayedSegments[entry.key]?.contains(index) ?? true) segment,
    ];
    final count = selected.fold(0, (count, segment) => count + segment.length);
    if (count <= maxiumumPointsDisplayed) {
      return reducedPoints = totalPoints > count ? count : null;
    }

    var remaining = min(
      maxiumumPointsDisplayed,
      max(minimumPointsNeeded, minimumPointsPerSegment * selected.length),
    );
    var remainingPoints = count;
    var retained = 0;
    for (final segment in selected) {
      if (segment.isEmpty) continue;
      final length = segment.length;
      final quota = (remaining * length) ~/ remainingPoints;
      _sampleInPlace(segment, quota);
      retained += segment.length;
      remaining -= quota;
      remainingPoints -= length;
    }
    return reducedPoints = retained;
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
    if (_arrayPointCounts.containsKey(channelName)) {
      clearChannel(channelName);
      return;
    }

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
        }
      }
      // After a purge the raw points array has been compacted: index 0 is now
      // what was index [pointsRemovedFromNextSegment].  Set lastProcessedIndex
      // to the last valid index in the compacted array so the next toSpots call
      // only appends truly new points rather than re-scanning from a stale
      // position that is now out of range.
      channelIdx[0] = remainingPointsInNextSegment - 1;
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

  void clearAll({bool clearDataLoggerState = true}) {
    spots.clear();
    tempSpot.clear();
    _arrayPointCounts.clear();
    lastProcessedIndex.clear();
    _lastNormalizedLimits.clear();

    _spotsMinX = null;
    _spotsMaxX = null;
    _spotsMinY = null;
    _spotsMaxY = null;

    totalPoints = 0;
    reducedPoints = null;
    _resetCache = false;

    if (clearDataLoggerState) clearDataLogger();
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
    _arrayPointCounts.remove(channelName);
    _lastNormalizedLimits.remove(channelName);
  }

  /// For array mode: clears every cached segment that is NOT in [keepSegments]
  /// for each channel. This prevents unbounded accumulation of waveform
  /// segments in the cache when only one (or a few) are ever displayed.
  ///
  /// Segment indices are preserved (not compacted) so that [toSpots] continues
  /// to receive the same segmentIndex values it uses to index into [points].
  ///
  /// [keepSegments] maps channelName → list of segment indices to retain.
  /// Cached channels absent from [keepSegments] are evicted.
  void retainSegments(
    Map<String, List<int>> keepSegments, {
    bool recount = true,
  }) {
    for (final channel in spots.keys.toList()) {
      if (!keepSegments.containsKey(channel)) clearChannel(channel);
    }
    for (final entry in keepSegments.entries) {
      final channelName = entry.key;
      final keep = entry.value.toSet();
      if (!spots.containsKey(channelName)) continue;

      final channelSpots = spots[channelName]!;
      final channelIdx = lastProcessedIndex[channelName]!;

      for (var i = 0; i < channelSpots.length; i++) {
        if (!keep.contains(i)) {
          // Clear the spot list but keep the slot so segment indices stay valid.
          channelSpots[i].clear();
          _arrayPointCounts[channelName]?.remove(i);
          if (i < channelIdx.length) channelIdx[i] = -1;
        }
      }
    }

    // Recount totalPoints after eviction.
    if (!recount) return;
    totalPoints = 0;
    for (final segs in spots.values) {
      for (final seg in segs) {
        totalPoints += seg.length;
      }
    }
  }
}
