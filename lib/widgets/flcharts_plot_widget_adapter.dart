part of plotadapter;

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  final bool isShowLabels;

  FlchartsPlotWidgetAdapter(
      {required super.widget, required this.isShowLabels});

  @override
  Widget buildPlot() => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          LineChart(LineChartData(
            clipData: const FlClipData.all(),
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            lineBarsData: plotReply == null
                ? []
                : _toLineChartBarDataList(plotReply!.data, filteredPoints),
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

    List<Widget> rowDataContents = [];

    for (var channelData in plotReply.data) {
      if (_channelHasError(channelData)) {
        continue;
      }
      rowDataContents.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              channelData.name,
              style: TextStyle(color: lineColorForChannel(channelData.name)),
            ),
            Text(
              " (${channelData.units})",
              style: TextStyle(color: lineColorForChannel(channelData.name)),
            )
          ])));
    }

    double axisNameSize = plotReply.data.length * 25;
    var axisNameWidget = Column(children: rowDataContents);

    if (wide) {
      // Displayed on wide screen
      leftTitles = AxisTitles(
        axisNameSize: axisNameSize,
        axisNameWidget: axisNameWidget,
        sideTitles: SideTitles(
          showTitles: isShowLabels, //zyuan true,
          reservedSize: 60,
        ),
      );

      topTitles = emptyTitles;
    } else {
      // Displayed on narrow screen
      leftTitles = AxisTitles(
        sideTitles: SideTitles(
          showTitles: isShowLabels, // zyuan true,
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
            sideTitles: SideTitles(
              showTitles: isShowLabels, // zyuan true,
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
      Map<String, List<PlotPoint>> filteredChannelPoints) {
    List<LineChartBarData> lineChartList = [];

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel) ||
          !filteredChannelPoints.containsKey(plotChannel.name)) {
        return;
      }

      var spots = _toSpots(filteredChannelPoints[plotChannel.name]!);

      lineChartList.add(LineChartBarData(
        color: lineColorForChannel(plotChannel.name),
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
