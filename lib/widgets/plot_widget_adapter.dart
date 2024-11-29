library plotadapter;

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:graphic/graphic.dart';

part 'flcharts_plot_widget_adapter.dart';
part 'graphic_plot_widget_adapter.dart';
part 'fermi_plot_widget_adapter.dart';

abstract class PlotWidgetAdapter {
  final PlotWidget widget;

  double minY = 0, maxY = 1.0;

  double minX = 0, maxX = 1.0;

  PlotWidgetAdapter({required this.widget});

  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits});

  List<List<PlotPoint>> _findLimits(
      {required List<PlotChannelData> plotChannels,
      required List<String> yLimits}) {
    List<List<PlotPoint>> filterPlotPoints = [];
    // Get the minX, minY, maxX, maxY accorss all channels.
    for (var plotChannel in plotChannels) {
      if (_channelHasError(plotChannel)) {
        continue;
      }
      final points = plotChannel.points;
      for (final point in points) {
        minY = min(point.y, minY);
        maxY = max(point.y, maxY);
        minX = min(point.x, minX);
        maxX = max(point.x, maxX);
      }
    }
    // Filter the data according to the configured minY and maxY.
    if (yLimits.isNotEmpty) {
      if (yLimits[0] != "") minY = double.parse(yLimits[0]);
      if (yLimits[1] != "") maxY = double.parse(yLimits[1]);
      for (var plotChannel in plotChannels) {
        if (_channelHasError(plotChannel)) {
          continue;
        }
        final points = plotChannel.points;
        final filteredPoints = yLimits.isNotEmpty
            ? points
                .where((PlotPoint point) => point.y >= minY && point.y <= maxY)
                .toList()
            : points;
        filterPlotPoints.add(filteredPoints);
      }
    }
    return filterPlotPoints;
  }

  Color _nextColorForIndex(String channelName) {
    var plotChannels = widget.plotChannels;
    ChannelSetting setting = plotChannels[channelName]!;

    // Find unique color
    if (setting.lineColor == null) {
      Color? candidateColor;
      List<Color> displayedColors = [];
      plotChannels.forEach((name, setting) {
        if (name != channelName) {
          if (setting.lineColor != null) {
            displayedColors.add(setting.lineColor!);
          }
        }
      });

      for (var plotColor in PlotColor.values) {
        if (displayedColors.contains(plotColor.color)) {
          continue;
        }
        candidateColor = plotColor.color;
        break;
      }

      // No more colors, default to blue.
      candidateColor ??= PlotColor.blue.color;
      setting.lineColor = candidateColor;
    }

    return setting.lineColor!;
  }

  bool _channelHasError(PlotChannelData chData) {
    return chData.status < 0;
  }
}
