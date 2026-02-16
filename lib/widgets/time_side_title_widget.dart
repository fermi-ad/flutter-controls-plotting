import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class TimeSideTitleWidget extends StatelessWidget {
  const TimeSideTitleWidget({
    super.key,
    required this.showMillis,
    required this.meta,
    required this.value,
  });

  final bool showMillis;
  final TitleMeta meta;
  final double value;

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      angle: -1.57, // -90 * 3.14 / 180,
      child: Text(parseDaqTimeAsString(value, showMillis: showMillis)),
    );
  }
}
