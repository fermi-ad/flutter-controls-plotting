import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_adapter.dart';

/// [`fl_chart`](https://pub.dev/packages/fl_chart) implementation for
/// categorical device bars.
///
/// [BarChartLayout.grouped] renders each [BarSegment] as an independent rod.
/// [BarChartLayout.stacked] maps renderer-neutral resolved intervals to one
/// fl_chart rod with contiguous stack items per device.
class FlChartBarAdapter extends BarChartAdapter {
  const FlChartBarAdapter();

  @override
  Widget build(BuildContext context, BarChartModel data) {
    final stackedSegments = data.style.layout == BarChartLayout.stacked
        ? <String, List<ResolvedBarSegment>>{
            for (final device in data.deviceNames)
              device: data.resolvedStackFor(device),
          }
        : const <String, List<ResolvedBarSegment>>{};
    final values = data.style.layout == BarChartLayout.stacked
        ? stackedSegments.values
              .expand((segments) => segments)
              .expand((segment) => [segment.start, segment.end])
              .toList()
        : data.deviceNames
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
              barRods: _barRodsFor(
                data,
                data.deviceNames[index],
                stackedSegments[data.deviceNames[index]],
              ),
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
              final unit = data.unitsByDevice[device];
              final suffix = unit == null || unit.isEmpty ? '' : ' $unit';
              if (data.style.layout == BarChartLayout.stacked) {
                final segments = stackedSegments[device] ?? const [];
                if (segments.isEmpty) return null;
                final lines = segments
                    .map(
                      (resolved) =>
                          '${resolved.segment.label}: '
                          '${resolved.start.toStringAsFixed(3)}–'
                          '${resolved.end.toStringAsFixed(3)}$suffix',
                    )
                    .join('\n');
                return BarTooltipItem(
                  '$device\n$lines',
                  const TextStyle(color: Colors.white),
                );
              }
              final segments = data.segmentsFor(device);
              if (rodIndex < 0 || rodIndex >= segments.length) return null;
              final segment = segments[rodIndex];
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

  List<BarChartRodData> _barRodsFor(
    BarChartModel data,
    String device,
    List<ResolvedBarSegment>? resolvedStack,
  ) {
    if (data.style.layout == BarChartLayout.stacked) {
      final segments = resolvedStack ?? const [];
      if (segments.isEmpty) return const [];
      return [
        BarChartRodData(
          toY: segments.last.end,
          width: data.style.segmentWidth,
          borderRadius: data.style.borderRadius,
          color: segments.last.segment.color,
          rodStackItems: [
            for (final resolved in segments)
              BarChartRodStackItem(
                resolved.start,
                resolved.end,
                resolved.segment.color,
              ),
          ],
        ),
      ];
    }

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
