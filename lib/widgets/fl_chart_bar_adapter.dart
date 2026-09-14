import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_adapter.dart';

/// [`fl_chart`](https://pub.dev/packages/fl_chart) implementation for
/// categorical, grouped device bars.
class FlChartBarAdapter extends BarChartAdapter {
  const FlChartBarAdapter();

  @override
  Widget build(BuildContext context, BarChartModel data) {
    final endpoints = data.deviceNames
        .expand(data.segmentsFor)
        .map((segment) => segment.toY)
        .toList();
    final calculatedMin = endpoints.isEmpty
        ? 0.0
        : endpoints.reduce((a, b) => a < b ? a : b);
    final calculatedMax = endpoints.isEmpty
        ? 1.0
        : endpoints.reduce((a, b) => a > b ? a : b);
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
        groupsSpace: 12,
        barGroups: [
          for (var index = 0; index < data.deviceNames.length; index++)
            BarChartGroupData(
              x: index,
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
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    data.deviceNames[index],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
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
              final unit = data.unitsByDevice[device];
              final suffix = unit == null || unit.isEmpty ? '' : ' $unit';
              final lines = segments
                  .map(
                    (segment) =>
                        '${segment.label}: ${segment.toY.toStringAsFixed(3)}$suffix',
                  )
                  .join('\\n');
              if (lines.isEmpty) return null;
              return BarTooltipItem(
                '$device\\n$lines',
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
    if (segments.isEmpty) return const [];
    final lastSegment = segments.last;
    return [
      BarChartRodData(
        toY: lastSegment.toY,
        width: data.style.rodWidth,
        borderRadius: data.style.borderRadius,
        rodStackItems: [
          for (final segment in segments)
            BarChartRodStackItem(
              segment.fromY,
              segment.toY,
              segment.style.color,
            ),
        ],
      ),
    ];
  }
}
