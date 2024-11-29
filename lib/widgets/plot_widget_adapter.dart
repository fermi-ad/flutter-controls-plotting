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

  double minY = 0, maxY = 0;

  PlotWidgetAdapter({required this.widget});

  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits});

  (double, double, double, double, List<List<FlSpot>>) _findLimits(
      {required List<PlotChannelData> plotChannels,
      required List<String> yLimits}) {
    double minY = 0.0;
    double maxY = 1.0;
    double minX = 0.0;
    double maxX = 1.0;
    List<List<FlSpot>> filteredChannelSpots = [];
    // Get the minX, minY, maxX, maxY accorss all channels.
    for (var plotChannel in plotChannels) {
      if (_channelHasError(plotChannel)) {
        continue;
      }
      List<FlSpot> spots = _toSpots(plotChannel.points);
      for (final spot in spots) {
        minY = min(spot.y, minY);
        maxY = max(spot.y, maxY);
        minX = min(spot.x, minX);
        maxX = max(spot.x, maxX);
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
        List<FlSpot> spots = _toSpots(plotChannel.points);
        List<FlSpot> filteredSpots = yLimits.isNotEmpty
            ? spots.where((spot) => spot.y >= minY && spot.y <= maxY).toList()
            : spots;
        filteredChannelSpots.add(filteredSpots);
      }
    }
    return (minX, minY, maxX, maxY, filteredChannelSpots);
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

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels,
      List<List<FlSpot>> filteredChannelSpots) {
    List<LineChartBarData> lineChartList = [];

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel)) {
        return;
      }

      var spots = filteredChannelSpots[index];

      lineChartList.add(LineChartBarData(
        color: _nextColorForIndex(plotChannel.name),
        spots: spots,
        isCurved: true,
        isStrokeCapRound: true,
        barWidth: 3,
        belowBarData: BarAreaData(
          show: false,
        ),
        dotData: const FlDotData(show: false),
      ));
    });

    return lineChartList;
  }

  bool _channelHasError(PlotChannelData chData) {
    return chData.status < 0;
  }
}
