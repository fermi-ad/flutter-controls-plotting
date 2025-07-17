import 'package:flutter/material.dart';

class PlotYAxisLabelWidget extends StatelessWidget {
  final double normalizedValue;
  final double value;
  final double? min;
  final double? max;

  const PlotYAxisLabelWidget(
      {super.key, required this.normalizedValue, this.min, this.max})
      : value = (normalizedValue * (max ?? 1) - (min ?? 0)) + (min ?? 0);

  @override
  Widget build(BuildContext context) {
    final text = value.toStringAsFixed(2);
    print("$min $max $normalizedValue $value");
    return Text(text);
  }
}
