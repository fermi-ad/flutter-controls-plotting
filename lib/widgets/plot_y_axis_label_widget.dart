import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';

class PlotYAxisLabelWidget extends StatelessWidget {
  final double normalizedValue;
  final Map<String, ChannelSetting> channels;
  final double? globalMin;
  final double? globalMax;

  const PlotYAxisLabelWidget(
      {super.key,
      required this.normalizedValue,
      required this.channels,
      this.globalMin,
      this.globalMax});

  @override
  Widget build(BuildContext context) {
    List<Text> labels = [];

    for (final channelName in channels.keys) {
      labels.add(Text(_calculateValue(channelName).toStringAsFixed(2),
          style: TextStyle(color: channels[channelName]!.lineColor)));
    }

    return Column(children: labels);
  }

  double _calculateValue(String channelName) =>
      (normalizedValue *
          ((channels[channelName]?.max ?? 1) -
              (channels[channelName]?.min ?? 0))) +
      (channels[channelName]?.min ?? 0);
}
