part of plotadapter;

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  FlchartsPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits}) {
    List<LineChartBarData> lineChartBarDataList;
    double minX, minY, maxX, maxY;
    List<List<PlotPoint>> filteredChannelPoints;

    if (plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      (minX, minY, maxX, maxY, filteredChannelPoints) =
          _findLimits(plotChannels: plotReply.data, yLimits: yLimits);
      lineChartBarDataList =
          _toLineChartBarDataList(plotReply.data, filteredChannelPoints);
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

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels,
      List<List<PlotPoint>> filteredChannelPoints) {
    List<LineChartBarData> lineChartList = [];

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel)) {
        return;
      }

      var spots = _toSpots(filteredChannelPoints[index]);

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
}
