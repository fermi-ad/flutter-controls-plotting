import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_segment.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_adapter.dart';

/// [`fl_chart`](https://pub.dev/packages/fl_chart) implementation for
/// categorical, grouped device bars.
///
/// Each device is rendered as a group containing one independent bar per
/// [BarSegment] the caller supplied — the adapter does not stack or derive
/// segments, it simply renders what [BarChartModel] holds.
class FlChartBarAdapter extends BarChartAdapter {
  const FlChartBarAdapter();

  @override
  Widget build(BuildContext context, BarChartModel data) {
    final values = data.deviceNames
        .expand(data.segmentsFor)
        .map((segment) => segment.value)
        .whereType<double>()
        .toList();
    final calculatedMin = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a < b ? a : b);
    final calculatedMax = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    final range = calculatedMax - calculatedMin;
    final padding = range == 0
        ? (calculatedMax.abs() * 0.1).clamp(1.0, double.infinity)
        : range * 0.1;

    return BarChart(
      BarChartData(
        minY:
            data.style.minY ??
            (calculatedMin < 0 ? calculatedMin - padding : 0),
        maxY: data.style.maxY ?? calculatedMax + padding,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: data.style.groupSpace,
        barGroups: [
          for (var index = 0; index < data.deviceNames.length; index++)
            BarChartGroupData(
              x: index,
              barsSpace: data.style.segmentSpace,
              barRods: _barRodsFor(data, data.deviceNames[index]),
            ),
        ],
        titlesData: FlTitlesData(
          show: data.style.showTitles,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 46),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: data.style.showTitles,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.deviceNames.length) {
                  return const SizedBox.shrink();
                }
                final device = data.deviceNames[index];
                final hasError = data.errorsByDevice.containsKey(device);
                return SideTitleWidget(
                  meta: meta,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasError) ...[
                        const Icon(
                          Icons.error_outline,
                          size: 12,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          device,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final device = data.deviceNames[group.x.toInt()];
              final segments = data.segmentsFor(device);
              if (rodIndex < 0 || rodIndex >= segments.length) return null;
              final segment = segments[rodIndex];
              final unit = data.unitsByDevice[device];
              final suffix = unit == null || unit.isEmpty ? '' : ' $unit';
              final valueText = segment.value == null
                  ? 'n/a'
                  : '${segment.value!.toStringAsFixed(3)}$suffix';
              return BarTooltipItem(
                '$device\n${segment.label}: $valueText',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  List<BarChartRodData> _barRodsFor(BarChartModel data, String device) {
    final segments = data.segmentsFor(device);
    return [
      for (final segment in segments)
        BarChartRodData(
          toY: segment.value ?? 0,
          width: data.style.segmentWidth,
          borderRadius: data.style.borderRadius,
          color: segment.color,
        ),
    ];
  }
}
