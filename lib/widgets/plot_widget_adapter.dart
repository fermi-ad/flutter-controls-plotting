library plotadapter;

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

  PlotReply? plotReply;

  double minY = 0, maxY = 1.0;

  double minX = 0, maxX = 1.0;

  List<List<PlotPoint>> filteredPoints = [[]];

  PlotWidgetAdapter({required this.widget});

  Widget buildPlot();

  Color lineColorForChannel(String channelName) {
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
