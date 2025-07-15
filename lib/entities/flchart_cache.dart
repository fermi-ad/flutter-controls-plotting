import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

class FlchartCache {
  Map<String, List<List<FlSpot>>> points = {};

  int spotsGenCtr = 0;

  List<FlSpot> toSpots(
      {required List<PlotPoint> points,
      double? minX,
      double? maxX,
      double? minY,
      double? maxY,
      bool exitForScalar = false}) {
    List<FlSpot> flSpots = [];

    // Find the closest points to each min and max
    PlotPoint? minXPair;
    PlotPoint? maxXPair;
    PlotPoint? minYPair;
    PlotPoint? maxYPair;

    int? minXPairIndex;
    int? maxXPairIndex;
    int? minYPairIndex;
    int? maxYPairIndex;

    for (PlotPoint point in points.reversed) {
      var x = point.x;
      var y = point.y;

      bool addPoint = true;

      if (!__isWithinBounds(x, minX, maxX)) {
        if ((maxX != null && x > maxX) &&
            (maxXPair == null || maxXPair.x > x)) {
          maxXPair = PlotPoint(x: x, y: y);
          maxXPairIndex = flSpots.length;
        } else if ((minX != null && x < minX) &&
            (minXPair == null || minXPair.x < x)) {
          minXPair = PlotPoint(x: x, y: y);
          minXPairIndex = flSpots.length;
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
          maxYPairIndex = flSpots.length;
        } else if ((minY != null && y < minY) &&
            (minYPair == null || minYPair.y < y)) {
          minYPair = PlotPoint(x: x, y: y);
          minYPairIndex = flSpots.length;
        }
        addPoint = false;
      }

      if (addPoint) {
        FlSpot flSpot = FlSpot(x, y);
        flSpots.insert(0, flSpot);
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
    var offset = flSpots.length;
    for (var entry in spotsToInsert.reversed) {
      var index = offset - entry.key;
      flSpots.insert(index, entry.value);
    }

    return flSpots;
  }

  bool __isWithinBounds(double value, double? min, double? max) {
    // Check if the given value is within the specified bounds (min and max).
    return (min == null || value >= min) && (max == null || value <= max);
  }
}
