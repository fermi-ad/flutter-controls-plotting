part of plotadapter;

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  final bool isShowLabels;

  final int maxiumumPointsDisplayed = 10000;

  FlchartsPlotWidgetAdapter(
      {required super.widget,
      required this.isShowLabels,
      super.plotReply}); // Update this line

  final GlobalKey chartKey = GlobalKey();

  @override
  Widget buildPlot() => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => LineChart(
          key: chartKey,
          duration: widget.plotAnimationDuration,
          LineChartData(
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
                touchCallback: handleTouchCallback),
            titlesData: _buildTitlesData(
                plotReply: plotReply, wide: constraints.maxWidth > 600),
          )));

  // Get the size of the LineChart Widget.
  Size? getChartSize() {
    final renderBox = chartKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  // Determine the closest tooltip data point for zooming purpose.
  void handleTouchCallback(FlTouchEvent event, LineTouchResponse? response) {
    if (event is FlPointerHoverEvent && response?.lineBarSpots != null) {
      final chartSize = getChartSize();
      if (chartSize == null) return;

      final touchPosition = event.localPosition;
      LineBarSpot? closestSpot;
      double minDistance = double.infinity;

      for (final spot in response!.lineBarSpots!) {
        final px = getPixelX(spot, chartSize);
        final py = getPixelY(spot, chartSize);
        final spotOffset = Offset(px, py);
        final distance = (touchPosition - spotOffset).distance;
        if (distance < minDistance) {
          minDistance = distance;
          closestSpot = spot;
        }
      }
      if (closestSpot != null) {
        widget.plotData.closestSpotX = closestSpot.x;
        widget.plotData.closestSpotY = closestSpot.y;
      }
    }
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

    List<Widget> rowDataContents = [];

    for (var channelData in plotReply.data) {
      if (_channelHasError(channelData)) {
        continue;
      }

      var chColor = lineColorForChannel(channelData.name);

      rowDataContents
          .add(PlotChannelTitle(channelData: channelData, chColor: chColor));
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
        meta: meta,
        angle: -1.57, // -90 * 3.14 / 180,
        child: Text(parseDaqTimeAsString(value)),
      );
    }

    return defaultGetTitle(value, meta);
  }

  double touchPointDistanceCalculate(
      {required Offset touchPoint,
      required Offset spotPixelCoordinates,
      required bool nearestPointXY}) {
    double distance = nearestPointXY
        // Determine distance nearest to the cursor.
        ? (touchPoint - spotPixelCoordinates).distance
        // Determine distance for all points on x axis.
        : (touchPoint.dx - spotPixelCoordinates.dx).abs();
    return distance;
  }

  // Converts a LineBarSpot's X data value to pixel position,
  // assuming full widget size is used for the plot area.
  double getPixelX(LineBarSpot touchedSpot, Size viewSize) {
    final deltaX = widget.plotData.maxX! - widget.plotData.minX!;
    if (deltaX == 0.0) {
      return 0;
    }
    return ((touchedSpot.x - widget.plotData.minX!) / deltaX) * viewSize.width;
  }

  // Converts a LineBarSpot's Y data value to pixel position,
  // assuming full widget size is used for the plot area.
  double getPixelY(LineBarSpot touchedSpot, Size viewSize) {
    final deltaY = widget.plotData.maxY! - widget.plotData.minY!;
    if (deltaY == 0.0) {
      return 0;
    }
    // Flip the Y axis, the smallest Y is at the top.
    final normalizedY = (touchedSpot.y - widget.plotData.minY!) / deltaY;
    return viewSize.height * (1 - normalizedY);
  }

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

  bool __isWithinBounds(double value, double? min, double? max) {
    // Check if the given value is within the specified bounds (min and max).
    return (min == null || value >= min) && (max == null || value <= max);
  }

  List<FlSpot> _toSpots(
      {required List<PlotPoint> points,
      double? minX,
      double? maxX,
      double? minY,
      double? maxY}) {
    List<FlSpot> flSpots = [];

    // Find the closest points to each min and max
    PlotPoint? minXPair;
    PlotPoint? maxXPair;
    PlotPoint? minYPair;
    PlotPoint? maxYPair;

    int? minXPairIndex;
    int? maxXPairIndex;
    int? minYPairIndex;
    int? maxYPairIndex;

    // Timed X axis and no xMax defined will exit upon last out of range value.
    bool exitForScalar = widget.xMax == null && widget.isTimedXAxis;

    for (PlotPoint point in points.reversed) {
      var x = point.x;
      var y = point.y;

      bool addPoint = true;

      if (!__isWithinBounds(x, minX, maxX)) {
        if ((maxX != null && x > maxX) &&
            (maxXPair == null || maxXPair.x > x)) {
          maxXPair = PlotPoint(x: x, y: y);
          maxXPairIndex = flSpots.length;
        } else if ((minX != null && x < minX) &&
            (minXPair == null || minXPair.x < x)) {
          minXPair = PlotPoint(x: x, y: y);
          minXPairIndex = flSpots.length;
          if (exitForScalar) {
            // The last relevant time was reached. No need to check rest of points.
            break;
          }
        }
        addPoint = false;
      }

      if (!__isWithinBounds(y, minY, maxY)) {
        if ((maxY != null && y > maxY) &&
            (maxYPair == null || maxYPair.y > y)) {
          maxYPair = PlotPoint(x: x, y: y);
          maxYPairIndex = flSpots.length;
        } else if ((minY != null && y < minY) &&
            (minYPair == null || minYPair.y < y)) {
          minYPair = PlotPoint(x: x, y: y);
          minYPairIndex = flSpots.length;
        }
        addPoint = false;
      }

      if (addPoint) {
        FlSpot flSpot = FlSpot(x, y);
        flSpots.insert(0, flSpot);
      }
    }

    // Collect the indices and corresponding FlSpot objects
    final List<MapEntry<int, FlSpot>> spotsToInsert = [];

    if (minXPairIndex != null) {
      spotsToInsert
          .add(MapEntry(minXPairIndex, FlSpot(minXPair!.x, minXPair.y)));
    }
    if (maxXPairIndex != null) {
      spotsToInsert
          .add(MapEntry(maxXPairIndex, FlSpot(maxXPair!.x, maxXPair.y)));
    }
    if (minYPairIndex != null) {
      spotsToInsert
          .add(MapEntry(minYPairIndex, FlSpot(minYPair!.x, minYPair.y)));
    }
    if (maxYPairIndex != null) {
      spotsToInsert
          .add(MapEntry(maxYPairIndex, FlSpot(maxYPair!.x, maxYPair.y)));
    }

    // Sort the list by indices in descending order
    spotsToInsert.sort((a, b) => b.key.compareTo(a.key));

    // Insert the FlSpot objects into flSpots in order from largest index to smallest
    var offset = flSpots.length;
    for (var entry in spotsToInsert.reversed) {
      var index = offset - entry.key;
      flSpots.insert(index, entry.value);
    }

    return flSpots;
  }

  List<FlSpot> _reduceSpots(
      {required List<FlSpot> spots, required int reductionFactor}) {
    for (int i = spots.length - 2; i >= 0; i--) {
      if (i % reductionFactor != 0) {
        spots.removeAt(i);
      }
    }

    return spots;
  }

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels, PlotData plotData) {
    List<LineChartBarData> lineChartList = [];

    var points = plotData.points;
    var minX = plotData.minX;
    var maxX = plotData.maxX;

    int numberOfPoints = 0;

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel) ||
          !points.containsKey(plotChannel.name)) {
        return;
      }

      for (var pointSegment in points[plotChannel.name]!) {
        // min and max y is not passed in for limiting points. This can cause behavior where poitns in the middle of axis are dropped.
        var spots = _toSpots(points: pointSegment, minX: minX, maxX: maxX);
        numberOfPoints += spots.length;

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

    // Verify if points reduction should be performed.
    if (numberOfPoints > maxiumumPointsDisplayed) {
      int reductionFactor = (numberOfPoints / maxiumumPointsDisplayed).ceil();
      var reducedSpots = _reduceSpots(
          spots: lineChartList.first.spots, reductionFactor: reductionFactor);
      reducedPoints = reducedSpots.length;
    }

    widget.plotMetadata.numberOfPoints = numberOfPoints;

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
      //return FlDotData(
      //show: true, // Show dots
      //getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
      //radius: 4, // Set the size of the dots
      //color: channelColor, // Set the color of the dots
      //strokeWidth: 2,
      //),
      //);
      return FlDotData(
        show: true, // Show icon circle
        getDotPainter: (spot, percent, bar, index) => CustomDotPainter(
          size: 10, // Set the size of the character
          color: channelColor, // Set the color of the character
          character: 'o', // Set the character to be used as the marker
          icon: Icons.radio_button_unchecked,
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
