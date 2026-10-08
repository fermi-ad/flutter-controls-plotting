import 'dart:math' as math;

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
    final minY =
        data.style.minY ?? (calculatedMin < 0 ? calculatedMin - padding : 0);
    final maxY = data.style.maxY ?? calculatedMax + padding;
    final yAxisInterval = data.style.yAxisDivisions == null
        ? null
        : (maxY - minY) / data.style.yAxisDivisions!;
    final xAxisRotation = data.style.xAxisLabelRotation * math.pi / 180;
    final bottomTitleReservedSize = _bottomTitleReservedSize(
      context,
      data.deviceNames,
      xAxisRotation,
    );

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: data.style.groupSpace,
        gridData: FlGridData(
          horizontalInterval: yAxisInterval,
          drawVerticalLine: false,
        ),
        barGroups: [
          for (var index = 0; index < data.deviceNames.length; index++)
            BarChartGroupData(
              x: index,
              barsSpace: data.style.segmentSpace,
              barRods: _barRodsFor(
                data,
                data.deviceNames[index],
                stackedSegments[data.deviceNames[index]],
                minY,
                maxY,
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
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: data.style.showTitles,
              reservedSize: 56,
              interval: yAxisInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatYAxisValue(data.style, value, yAxisInterval),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: data.style.showTitles,
              reservedSize: bottomTitleReservedSize,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.deviceNames.length) {
                  return const SizedBox.shrink();
                }
                final device = data.deviceNames[index];
                final hasError = data.errorsByDevice.containsKey(device);
                return SideTitleWidget(
                  meta: meta,
                  // Preserve the original fl_chart chart-to-title gap at every
                  // angle. The zero-height rotated anchor prevents the title
                  // reservation from becoming additional visible whitespace.
                  space: 8,
                  child: _xAxisLabel(
                    device: device,
                    hasError: hasError,
                    rotationRadians: xAxisRotation,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            direction: TooltipDirection.auto,
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

  String _formatYAxisValue(
    BarChartStyle style,
    double value,
    double? interval,
  ) {
    final formatter = style.yAxisLabelFormatter;
    if (formatter != null) return formatter(value);
    if (interval == null || interval == 0 || !interval.isFinite) {
      return value.toString();
    }

    final absoluteInterval = interval.abs();
    final decimals = absoluteInterval >= 1
        ? 0
        : (-math.log(absoluteInterval) / math.ln10).ceil().clamp(0, 12);
    final fixed = value.toStringAsFixed(decimals);
    return fixed.contains('.')
        ? fixed
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  Widget _xAxisLabel({
    required String device,
    required bool hasError,
    required double rotationRadians,
  }) {
    final isUnrotated = _isUnrotated(rotationRadians);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasError) ...[
          const Icon(Icons.error_outline, size: 12, color: Colors.red),
          const SizedBox(width: 2),
        ],
        Text(
          device,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (isUnrotated) return label;

    // SideTitleWidget centers its child's layout bounds on the category. Give
    // it a zero-width anchor and rotate around the leading edge's midpoint, so
    // the bar meets the start of the label. The midpoint is essential at 90°:
    // it keeps the vertical center of the text aligned with the bar.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 0,
      heightFactor: 0,
      child: Transform.rotate(
        angle: rotationRadians,
        alignment: Alignment.centerLeft,
        child: label,
      ),
    );
  }

  bool _isUnrotated(double rotationRadians) =>
      (rotationRadians / math.pi).remainder(1).abs() < 1e-9;

  double _bottomTitleReservedSize(
    BuildContext context,
    List<String> deviceNames,
    double rotationRadians,
  ) {
    if (_isUnrotated(rotationRadians)) return 48;

    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final longestLabel = deviceNames.fold<String>(
      '',
      (longest, device) => device.length > longest.length ? device : longest,
    );
    final painter = TextPainter(
      text: TextSpan(text: longestLabel),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 2,
    )..layout();
    final sine = math.sin(rotationRadians).abs();
    final cosine = math.cos(rotationRadians).abs();
    // Reserve the rotated label's painted vertical extent. This prevents
    // clipping while SideTitleWidget.space remains zero at every angle.
    return math.max(48, painter.width * sine + painter.height * cosine);
  }

  List<BarChartRodData> _barRodsFor(
    BarChartModel data,
    String device,
    List<ResolvedBarSegment>? resolvedStack,
    double minY,
    double maxY,
  ) {
    if (data.style.layout == BarChartLayout.stacked) {
      final segments = resolvedStack ?? const [];
      if (segments.isEmpty) return const [];
      final visibleSegments = [
        for (final resolved in segments)
          _clampStackSegment(resolved, minY, maxY),
      ].whereType<ResolvedBarSegment>().toList();
      if (visibleSegments.isEmpty) return const [];
      final extent = _stackExtent(visibleSegments);
      return [
        BarChartRodData(
          fromY: extent.$1,
          toY: extent.$2,
          width: data.style.segmentWidth,
          borderRadius: data.style.borderRadius,
          color: visibleSegments.last.segment.color,
          rodStackItems: [
            for (final resolved in visibleSegments)
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
        if (_clampRod(0, segment.value ?? 0, minY, maxY) case final visible?)
          BarChartRodData(
            fromY: visible.$1,
            toY: visible.$2,
            width: data.style.segmentWidth,
            borderRadius: data.style.borderRadius,
            color: segment.color,
          ),
    ];
  }

  (double, double)? _clampRod(
    double fromY,
    double toY,
    double minY,
    double maxY,
  ) {
    final clampedFromY = fromY.clamp(minY, maxY).toDouble();
    final clampedToY = toY.clamp(minY, maxY).toDouble();
    return clampedFromY == clampedToY ? null : (clampedFromY, clampedToY);
  }

  (double, double) _stackExtent(List<ResolvedBarSegment> segments) {
    final values = segments.expand((segment) => [segment.start, segment.end]);
    return (values.reduce(math.min), values.reduce(math.max));
  }

  ResolvedBarSegment? _clampStackSegment(
    ResolvedBarSegment segment,
    double minY,
    double maxY,
  ) {
    final visible = _clampRod(segment.start, segment.end, minY, maxY);
    if (visible == null) return null;
    return ResolvedBarSegment(
      segment: segment.segment,
      start: visible.$1,
      end: visible.$2,
    );
  }
}
