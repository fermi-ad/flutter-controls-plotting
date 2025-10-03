import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';

class PlotYAxisLabelWidget extends StatelessWidget {
  final double normalizedValue;
  final Map<String, ChannelSetting> channels;
  final double? defaultMin;
  final double? defaultMax;

  const PlotYAxisLabelWidget({
    super.key,
    required this.normalizedValue,
    required this.channels,
    this.defaultMin,
    this.defaultMax,
  });

  @override
  Widget build(BuildContext context) {
    List<Text> labels = [];

    for (final channelName in channels.keys) {
      final label = _formatValue(_calculateValue(channelName));

      labels.add(
        Text(label, style: TextStyle(color: channels[channelName]!.lineColor)),
      );
    }

    return Column(children: labels);
  }

  String _formatValue(double v) => v.toStringAsFixed(2);

  double _calculateValue(String channelName) {
    final channel = channels[channelName];
    if (channel != null && channel.isLogScale) {
      final logMin =
          channel.displayedMinY ??
          (defaultMin != null ? log(defaultMin!) : log(1));
      final logMax =
          channel.displayedMaxY ??
          (defaultMax != null ? log(defaultMax!) : log(10));

      // Calculate the log value at this normalized position
      final logValue = normalizedValue * (logMax - logMin) + logMin;

      // Convert back to linear scale for display
      final linearValue = exp(logValue);

      return linearValue;
    } else {
      final min = channel?.labelMinY ?? defaultMin ?? 0;
      final max = channel?.labelMaxY ?? defaultMax ?? 1;

      return normalizedValue * (max - min) + min;
    }
  }
}
