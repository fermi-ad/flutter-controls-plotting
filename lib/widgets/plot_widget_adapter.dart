// ignore_for_file: invalid_use_of_protected_member

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

  //int plotMarker = 0;

  Map<String, List<PlotPoint>> filteredPoints = {};

  PlotWidgetAdapter({required this.widget});

  Widget buildPlot();
  /*
  PlotMarker getTheMarker() {
     widget.onInternalChannelSettingChange?.call("some");
    return widget.plotMarker;
  }
   */

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

      widget.onInternalChannelSettingChange?.call(channelName);
    }

    return setting.lineColor!;
  }

String markerIndexForChannel(String channelName) {
  var plotChannels = widget.plotChannels;
  ChannelSetting setting = plotChannels[channelName]!;

  // Find unique marker index
  if (setting.plotMarker == null) {
    String? candidateMarkerIndex;
    List<String> displayedMarkerIndices = [];
    plotChannels.forEach((name, setting) {
      if (name != channelName) {
        if (setting.plotMarker != null) {
          displayedMarkerIndices.add(setting.plotMarker!.index.toString());
        }
      }
    });

    for (var plotMarker in PlotMarker.values) {
      if (displayedMarkerIndices.contains(plotMarker.index.toString())) {
        continue;
      }
      candidateMarkerIndex = plotMarker.index.toString();
      break;
    }

    // No more unique markers, default to "0" (Circle).
    candidateMarkerIndex ??= PlotMarker.zero.index.toString();
    setting.plotMarker = PlotMarker.values[int.parse(candidateMarkerIndex)];

    widget.onInternalChannelSettingChange?.call(channelName);
  }



  return setting.plotMarker!.markerIndex;
}




  bool _channelHasError(PlotChannelData chData) {
    return chData.status < 0;
  }
}


class CustomDotPainter extends FlDotPainter {
  final double size;
  final Color color;
  final String? character;
  final IconData? icon;

  CustomDotPainter({required this.size, required this.color, this.character, this.icon});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    if (icon != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontSize: size,
            fontFamily: icon!.fontFamily,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2));
    } else if (character != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            fontSize: size,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(size, size);
  }

  @override
  Color get mainColor => color;

  @override
  List<Object?> get props => [size, color, character, icon];

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    throw UnimplementedError('lerp is not implemented');
  }
}