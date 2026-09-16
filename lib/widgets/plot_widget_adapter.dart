// ignore_for_file: invalid_use_of_protected_member

library;

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/plotting_fl_spot.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_channel_title.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
import 'package:flutter_controls_plotting/widgets/time_side_title_widget.dart';
import 'package:graphic/graphic.dart';

part 'flcharts_plot_widget_adapter.dart';
part 'graphic_plot_widget_adapter.dart';
part 'fermi_plot_widget_adapter.dart';

abstract class PlotWidgetAdapter {
  final PlotWidget plotWidget;

  PlotReply? plotReply;

  PlotWidgetAdapter({required this.plotWidget, this.plotReply});

  Widget buildPlot();

  Color lineColorForChannel(String channelName, {bool dim = false}) {
    var plotChannels = plotWidget.plotChannels;
    ChannelSetting setting = plotChannels[channelName]!.channelSetting;

    // Find unique color
    if (setting.lineColor == null) {
      Color? candidateColor;
      List<Color> displayedColors = [];
      plotChannels.forEach((name, channelMetadata) {
        final setting = channelMetadata.channelSetting;
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

      plotWidget.onInternalChannelSettingChange?.call(channelName);
    }

    var color = setting.lineColor!;

    if (dim) {
      return color.withValues(alpha: 0.3);
    }

    return color;
  }

  int markerIndexForChannel(String channelName) {
    var plotChannels = plotWidget.plotChannels;
    ChannelSetting setting = plotChannels[channelName]!.channelSetting;
    return setting.plotMarker.markerIndex;
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

  CustomDotPainter({
    required this.size,
    required this.color,
    this.character,
    this.icon,
  });

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
      textPainter.paint(
        canvas,
        offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    } else if (character != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(fontSize: size, color: color),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2),
      );
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
