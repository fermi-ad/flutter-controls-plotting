import 'package:flutter_controls_core/flutter_controls_core.dart';

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
