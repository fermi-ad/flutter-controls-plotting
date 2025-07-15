import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

class FlchartCache {
  Map<String, List<List<FlSpot>>> spots = {};
  Map<String, List<int>> lastProcessedIndex = {};

  List<FlSpot> toSpots(
      {required List<PlotPoint> points,
      required channelName,
      required int segmentIndex,
      double? minX,
      double? maxX,
      double? minY,
      double? maxY,
      bool exitForScalar = false}) {
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
        FlSpot flSpot = FlSpot(x, y);
        newSpots.insert(0, flSpot);
      }
    }

    // Collect the indices and corresponding FlSpot objects
    final List<MapEntry<int, FlSpot>> spotsToInsert = [];

    if (minXPairIndex != null) {
      spotsToInsert
          .add(MapEntry(minXPairIndex, FlSpot(minXPair!.x, minXPair.y)));
    }
    if (maxXPairIndex != null) {
      spotsToInsert
          .add(MapEntry(maxXPairIndex, FlSpot(maxXPair!.x, maxXPair.y)));
    }
    if (minYPairIndex != null) {
      spotsToInsert
          .add(MapEntry(minYPairIndex, FlSpot(minYPair!.x, minYPair.y)));
    }
    if (maxYPairIndex != null) {
      spotsToInsert
          .add(MapEntry(maxYPairIndex, FlSpot(maxYPair!.x, maxYPair.y)));
    }

    // Sort the list by indices in descending order
    spotsToInsert.sort((a, b) => b.key.compareTo(a.key));

    // Insert the FlSpot objects into flSpots in order from largest index to smallest
    var offset = newSpots.length;
    for (var entry in spotsToInsert.reversed) {
      var index = offset - entry.key;
      newSpots.insert(index, entry.value);
    }

    flSpots.addAll(newSpots);

    spots[channelName]![segmentIndex] = flSpots;
    lastProcessedIndex[channelName]![segmentIndex] = points.length - 1;
    return flSpots;
  }

  bool __isWithinBounds(double value, double? min, double? max) {
    // Check if the given value is within the specified bounds (min and max).
    return (min == null || value >= min) && (max == null || value <= max);
  }
}
