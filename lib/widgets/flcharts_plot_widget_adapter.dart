import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:graphic/graphic.dart';

abstract class PlotWidgetAdapter {
  final PlotWidget widget;

  double minY = 0, maxY = 0;

  PlotWidgetAdapter({required this.widget});

  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits});

  (double, double, double, double, List<List<FlSpot>>) _findLimits(
      {required List<PlotChannelData> plotChannels,
      required List<String> yLimits}) {
    double minY = 0.0;
    double maxY = 1.0;
    double minX = 0.0;
    double maxX = 1.0;
    List<List<FlSpot>> filteredChannelSpots = [];
    // Get the minX, minY, maxX, maxY accorss all channels.
    for (var plotChannel in plotChannels) {
      if (_channelHasError(plotChannel)) {
        continue;
      }
      List<FlSpot> spots = _toSpots(plotChannel.points);
      for (final spot in spots) {
        minY = min(spot.y, minY);
        maxY = max(spot.y, maxY);
        minX = min(spot.x, minX);
        maxX = max(spot.x, maxX);
      }
    }
    // Filter the data according to the configured minY and maxY.
    if (yLimits.isNotEmpty) {
      if (yLimits[0] != "") minY = double.parse(yLimits[0]);
      if (yLimits[1] != "") maxY = double.parse(yLimits[1]);
      for (var plotChannel in plotChannels) {
        if (_channelHasError(plotChannel)) {
          continue;
        }
        List<FlSpot> spots = _toSpots(plotChannel.points);
        List<FlSpot> filteredSpots = yLimits.isNotEmpty
            ? spots.where((spot) => spot.y >= minY && spot.y <= maxY).toList()
            : spots;
        filteredChannelSpots.add(filteredSpots);
      }
    }
    return (minX, minY, maxX, maxY, filteredChannelSpots);
  }

  Color _nextColorForIndex(String channelName) {
    var plotChannels = widget.plotChannels;
    ChannelSetting setting = plotChannels[channelName]!;

    // Find unique color
    if (setting.lineColor == null) {
      Color? candidateColor;
      List<Color> displayedColors = [];
      plotChannels.forEach((name, setting) {
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
    }

    return setting.lineColor!;
  }

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels,
      List<List<FlSpot>> filteredChannelSpots) {
    List<LineChartBarData> lineChartList = [];

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel)) {
        return;
      }

      var spots = filteredChannelSpots[index];

      lineChartList.add(LineChartBarData(
        color: _nextColorForIndex(plotChannel.name),
        spots: spots,
        isCurved: true,
        isStrokeCapRound: true,
        barWidth: 3,
        belowBarData: BarAreaData(
          show: false,
        ),
        dotData: const FlDotData(show: false),
      ));
    });

    return lineChartList;
  }

  bool _channelHasError(PlotChannelData chData) {
    return chData.status < 0;
  }
}

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits}) {
    double minX, minY, maxX, maxY;
    List<List<FlSpot>> filteredChannelSpots;

    if (plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      (minX, minY, maxX, maxY, filteredChannelSpots) =
          _findLimits(plotChannels: plotReply.data, yLimits: yLimits);
    } else {
      // Defaults
      (minX, minY, maxX, maxY) = (0.0, 0.0, 1.0, 1.0);
    }

    super.minY = minY;
    super.maxY = maxY;

    return Chart(
      data: const [
        {'index': 0, 'v': 0},
        {
          'index': 1,
          'v': 1
        }, /*
          {'index': 2, 'v': 2},
          {'index': 3, 'v': 3},
          {'index': 4, 'v': 4},*/
      ],
      variables: {
        'index': Variable(
          accessor: (Map map) => map['index'] as num,
        ),
        'v': Variable(
          accessor: (Map map) => map['v'] as num,
        ),
      },
      marks: [
        LineMark(
          shape: ShapeEncode(value: BasicLineShape(dash: [5, 2])),
          selected: {
            'touchMove': {1}
          },
        )
      ],
      coord: RectCoord(color: const Color(0xffdddddd)),
      axes: [
        Defaults.horizontalAxis,
        Defaults.verticalAxis,
      ],
      selections: {
        'touchMove': PointSelection(
          on: {
            GestureType.scaleUpdate,
            GestureType.tapDown,
            GestureType.longPressMoveUpdate
          },
          dim: Dim.x,
        )
      },
      tooltip: TooltipGuide(
        followPointer: [false, true],
        align: Alignment.topLeft,
        offset: const Offset(-20, -20),
      ),
      crosshair: CrosshairGuide(followPointer: [false, true]),
    );
  }
}

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  FlchartsPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits}) {
    List<LineChartBarData> lineChartBarDataList;
    double minX, minY, maxX, maxY;
    List<List<FlSpot>> filteredChannelSpots;

    if (plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      (minX, minY, maxX, maxY, filteredChannelSpots) =
          _findLimits(plotChannels: plotReply.data, yLimits: yLimits);
      lineChartBarDataList =
          _toLineChartBarDataList(plotReply.data, filteredChannelSpots);
    } else {
      // Defaults
      lineChartBarDataList = [];
      (minX, minY, maxX, maxY) = (0.0, 0.0, 1.0, 1.0);
    }

    super.minY = minY;
    super.maxY = maxY;

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            LineChart(LineChartData(
              minX: minX,
              maxX: maxX,
              minY: super.minY,
              maxY: super.maxY,
              lineBarsData: lineChartBarDataList,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  maxContentWidth: 100,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (touchedSpot) => Colors.black,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final textStyle = TextStyle(
                        color: touchedSpot.bar.gradient?.colors[0] ??
                            touchedSpot.bar.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      );
                      return LineTooltipItem(
                        '${touchedSpot.x}, ${touchedSpot.y.toStringAsFixed(2)}',
                        textStyle,
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchLineStart: (data, index) => 0,
              ),
              titlesData: _buildTitlesData(
                  plotReply: plotReply, wide: constraints.maxWidth > 600),
            )));
  }

  FlTitlesData _buildTitlesData(
      {required PlotReply? plotReply, required bool wide}) {
    // List<String> channelNames, List<String> channelUnits, String xAxisLabel) {
    if (plotReply == null) {
      return const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );
    }

    final xAxisLabel = plotReply.xAxisUnits;

    const emptyTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

    final AxisTitles leftTitles;
    final AxisTitles topTitles;

    List<Row> rowDataContents = [];

    for (var channelData in plotReply.data) {
      if (_channelHasError(channelData)) {
        continue;
      }
      rowDataContents
          .add(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          channelData.name,
          style: TextStyle(color: _nextColorForIndex(channelData.name)),
        ),
        Text(
          " (${channelData.units})",
          style: TextStyle(color: _nextColorForIndex(channelData.name)),
        )
      ]));
    }

    double axisNameSize = plotReply.data.length * 20;
    var axisNameWidget = Column(children: rowDataContents);

    if (wide) {
      // Displayed on wide screen
      leftTitles = AxisTitles(
        axisNameSize: axisNameSize,
        axisNameWidget: axisNameWidget,
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 60,
        ),
      );

      topTitles = emptyTitles;
    } else {
      // Displayed on narrow screen
      leftTitles = const AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
        ),
      );

      topTitles = AxisTitles(
        axisNameSize: axisNameSize,
        axisNameWidget: axisNameWidget,
        sideTitles: const SideTitles(showTitles: false),
      );
    }

    return FlTitlesData(
        leftTitles: leftTitles,
        bottomTitles: AxisTitles(
            axisNameWidget: Text(
              xAxisLabel,
              style: const TextStyle(),
            ),
            sideTitles: const SideTitles(
              showTitles: true,
              reservedSize: 40,
            )),
        topTitles: topTitles,
        rightTitles: emptyTitles);
  }
}
