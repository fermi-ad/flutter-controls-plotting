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
      final label = _calculateValue(channelName).toStringAsFixed(2);

      labels.add(
        Text(label, style: TextStyle(color: channels[channelName]!.lineColor)),
      );
    }

    return Column(children: labels);
  }

  double _calculateValue(String channelName) =>
      normalizedValue * (_max(channelName) - _min(channelName)) +
      _min(channelName);

  double _min(String channelName) =>
      channels[channelName]?.finalMinY ?? defaultMin ?? 0;

  double _max(String channelName) =>
      channels[channelName]?.finalMaxY ?? defaultMax ?? 1;
}
