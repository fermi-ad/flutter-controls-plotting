part of plotadapter;

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  final bool isShowLabels;
  //final PlotMarker theMarker;

  FlchartsPlotWidgetAdapter(
      {required super.widget, required this.isShowLabels}); // Update this line

  @override
  Widget buildPlot() => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          LineChart(LineChartData(
            clipData: const FlClipData.all(),
            minX: widget.plotData.minX,
            maxX: widget.plotData.maxX,
            minY: widget.plotData.minY,
            maxY: widget.plotData.maxY,
            lineBarsData: plotReply == null
                ? []
                : _toLineChartBarDataList(plotReply!.data, widget.plotData),
            lineTouchData: LineTouchData(
              distanceCalculator:
                  (Offset touchPoint, Offset spotPixelCoordinates) =>
                      touchPointDistanceCalculate(
                          touchPoint: touchPoint,
                          spotPixelCoordinates: spotPixelCoordinates,
                          nearestPointXY: widget.plotData.scalarEventMode),
              touchTooltipData: LineTouchTooltipData(
                maxContentWidth: 100,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (touchedSpot) => Colors.black,
                getTooltipItems: (touchedSpots) =>
                    _generateLineTooltipItem(touchedSpots: touchedSpots),
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
          showTitles: isShowLabels,
          reservedSize: 60,
        ),
      );

      topTitles = emptyTitles;
    } else {
      // Displayed on narrow screen
      leftTitles = AxisTitles(
        sideTitles: SideTitles(
          showTitles: isShowLabels,
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
              showTitles: isShowLabels,
              reservedSize: widget.isTimedXAxis ? 80 : 40,
              getTitlesWidget: (value, meta) {
                return _bottomTitleWidgets(value, meta);
              },
            )),
        topTitles: topTitles,
        rightTitles: emptyTitles);
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    if (widget.isTimedXAxis) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        angle: -1.57, // -90 * 3.14 / 180,
        child: Text(parseDaqTimeAsString(value)),
      );
    }

    return defaultGetTitle(value, meta);
  }

  double touchPointDistanceCalculate(
          {required Offset touchPoint,
          required Offset spotPixelCoordinates,
          required bool nearestPointXY}) =>
      nearestPointXY
          // Determine distance nearest to the cursor.
          ? (touchPoint - spotPixelCoordinates).distance
          // Determine distance for all points on x axis.
          : (touchPoint.dx - spotPixelCoordinates.dx).abs();

  List<LineTooltipItem> _generateLineTooltipItem(
      {required List<LineBarSpot> touchedSpots}) {
    List<LineTooltipItem> tooltips = [];

    for (var touchedSpot in touchedSpots) {
      final x = touchedSpot.x;
      final y = touchedSpot.y;

      final textStyle = TextStyle(
        color: touchedSpot.bar.gradient?.colors[0] ?? touchedSpot.bar.color,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      );

      String xString;
      if (widget.isTimedXAxis) {
        xString = parseDaqTimeAsString(x);
      } else {
        xString = x.toString();
      }

      tooltips.add(LineTooltipItem(
        '$xString, ${y.toStringAsFixed(2)}',
        textStyle,
      ));
    }

    return tooltips;
  }

  List<FlSpot> _toSpots(List<PlotPoint> points) {
    return points
        .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
        .toList();
  }

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels, PlotData plotData) {
    List<LineChartBarData> lineChartList = [];

    var points = plotData.points;

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel) ||
          !points.containsKey(plotChannel.name)) {
        return;
      }

      for (var pointSegment in points[plotChannel.name]!) {
        var spots = _toSpots(pointSegment);

        lineChartList.add(LineChartBarData(
          color: lineColorForChannel(plotChannel.name),
          spots: spots,
          isCurved: false,
          belowBarData: BarAreaData(
            show: false,
          ),
          barWidth: markerIndexForChannel(plotChannel.name) == 0 ||
                  markerIndexForChannel(plotChannel.name) == 1
              ? 3
              : 0,
          //dotData: _selectFlDotData(int.parse(widget.plotMarker.markerIndex)  , lineColorForChannel(plotChannel.name)),
          dotData: _selectFlDotData(markerIndexForChannel(plotChannel.name),
              lineColorForChannel(plotChannel.name)),
        ));
      }
    });

    return lineChartList;
  }
}

FlDotData _selectFlDotData(int plotMarker, Color channelColor) {
  switch (plotMarker) {
    //  case 0 : line
    case 1: // line and dot
    case 2: //dot
      return FlDotData(
        show: true, // Show dots
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4, // Set the size of the dots
          color: channelColor, // Set the color of the dots
          strokeWidth: 0,
        ),
      );
    case 3: // circles
      return FlDotData(
        show: true, // Show dots
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4, // Set the size of the dots
          color: channelColor, // Set the color of the dots
          strokeWidth: 2,
        ),
      );
    case 4:
      return FlDotData(
        show: true, // Show cross dots
        getDotPainter: (spot, percent, bar, index) =>
            FlDotCrossPainter(color: channelColor, size: 10, width: 2),
      );
    case 5:
      return FlDotData(
        show: true, // Show square dots
        getDotPainter: (spot, percent, bar, index) =>
            FlDotSquarePainter(color: channelColor, size: 6, strokeWidth: 0),
      );
    case 6:
      return FlDotData(
        show: true, // Show letter 'O'
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'O', // Set the character to be used as the marker
        ),
      );
    case 7:
      return FlDotData(
        show: true, // Show letter 'K'
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'K', // Set the character to be used as the marker
        ),
      );
    case 8:
      return FlDotData(
        show: true, // Show letter 'V'
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'V', // Set the character to be used as the marker
        ),
      );
    case 9:
      return FlDotData(
        show: true, // Show icon hearts
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'o', // Set the character to be used as the marker
          icon: Icons.favorite_border,
        ),
      );
    case 10:
      return FlDotData(
        show: true, // Show icon arrow
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'o', // Set the character to be used as the marker
          icon: Icons.arrow_forward,
        ),
      );
    case 11:
      return FlDotData(
        show: true, // Show icon stars
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 14, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'o', // Set the character to be used as the marker
          icon: Icons.star_border_rounded,
        ),
      );
    case 12:
      return FlDotData(
        show: true, // Show icon triangle
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 14, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'o', // Set the character to be used as the marker
          icon: Icons.change_history,
        ),
      );
    default:
      return const FlDotData(show: false);
  }
}
