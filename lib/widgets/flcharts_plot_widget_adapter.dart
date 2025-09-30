part of plotadapter;

class FlchartsPlotWidgetAdapter extends PlotWidgetAdapter {
  final bool isShowLabels;

  final int maxiumumPointsDisplayed = 10000;

  FlchartsPlotWidgetAdapter({
    required super.plotWidget,
    required this.isShowLabels,
    super.plotReply,
  }); // Update this line

  final GlobalKey chartKey = GlobalKey();

  @override
  Widget buildPlot() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => LineChart(
      key: chartKey,
      duration: plotWidget.plotAnimationDuration,
      LineChartData(
        clipData: const FlClipData.all(),
        minX: plotWidget.plotData.minX,
        maxX: plotWidget.plotData.maxX,
        minY: 0,
        maxY: 1,
        lineBarsData: plotReply == null
            ? []
            : _toLineChartBarDataList(plotReply!.data, plotWidget.plotData),
        lineTouchData: LineTouchData(
          distanceCalculator:
              (Offset touchPoint, Offset spotPixelCoordinates) =>
                  touchPointDistanceCalculate(
                    touchPoint: touchPoint,
                    spotPixelCoordinates: spotPixelCoordinates,
                    nearestPointXY: plotWidget.plotData.scalarEventMode,
                  ),
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
          touchCallback: handleTouchCallback,
        ),
        titlesData: _buildTitlesData(
          plotReply: plotReply,
          wide: constraints.maxWidth > 600,
        ),
      ),
    ),
  );

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
        plotWidget.plotData.closestSpotX = closestSpot.x;
        plotWidget.plotData.closestSpotY = closestSpot.y;
      }
    }
  }

  FlTitlesData _buildTitlesData({
    required PlotReply? plotReply,
    required bool wide,
  }) {
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

      rowDataContents.add(
        PlotChannelTitle(channelData: channelData, chColor: chColor),
      );
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
          interval: _calculateYAxisLabelInterval(
            forNChannels: plotReply.data.length,
          ),
          reservedSize: 60,
          getTitlesWidget: _buildYLabelWidget,
        ),
      );

      topTitles = emptyTitles;
    } else {
      // Displayed on narrow screen
      leftTitles = AxisTitles(
        sideTitles: SideTitles(
          showTitles: isShowLabels,
          interval: _calculateYAxisLabelInterval(
            forNChannels: plotReply.data.length,
          ),
          reservedSize: 60,
          getTitlesWidget: _buildYLabelWidget,
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
        axisNameWidget: Text(xAxisLabel, style: const TextStyle()),
        sideTitles: SideTitles(
          showTitles: isShowLabels,
          reservedSize: plotWidget.isTimedXAxis ? 80 : 40,
          getTitlesWidget: (value, meta) {
            return _bottomTitleWidgets(value, meta);
          },
        ),
      ),
      topTitles: topTitles,
      rightTitles: emptyTitles,
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    if (plotWidget.isTimedXAxis) {
      return SideTitleWidget(
        meta: meta,
        angle: -1.57, // -90 * 3.14 / 180,
        child: Text(parseDaqTimeAsString(value)),
      );
    }

    return defaultGetTitle(value, meta);
  }

  SideTitleWidget _buildYLabelWidget(double value, TitleMeta meta) =>
      SideTitleWidget(
        meta: meta,
        child: PlotYAxisLabelWidget(
          channels: plotWidget.plotChannels,
          normalizedValue: value,
          defaultMin: plotWidget.plotData.minY,
          defaultMax: plotWidget.plotData.maxY,
        ),
      );

  double touchPointDistanceCalculate({
    required Offset touchPoint,
    required Offset spotPixelCoordinates,
    required bool nearestPointXY,
  }) {
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
    final deltaX = plotWidget.plotData.maxX! - plotWidget.plotData.minX!;
    if (deltaX == 0.0) {
      return 0;
    }
    return ((touchedSpot.x - plotWidget.plotData.minX!) / deltaX) *
        viewSize.width;
  }

  // Converts a LineBarSpot's Y data value to pixel position,
  // assuming full widget size is used for the plot area.
  double getPixelY(LineBarSpot touchedSpot, Size viewSize) {
    final deltaY = plotWidget.plotData.maxY! - plotWidget.plotData.minY!;
    if (deltaY == 0.0) {
      return 0;
    }
    // Flip the Y axis, the smallest Y is at the top.
    final normalizedY = (touchedSpot.y - plotWidget.plotData.minY!) / deltaY;
    return viewSize.height * (1 - normalizedY);
  }

  List<LineTooltipItem> _generateLineTooltipItem({
    required List<LineBarSpot> touchedSpots,
  }) {
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
      if (plotWidget.isTimedXAxis) {
        xString = parseDaqTimeAsString(x);
      } else {
        xString = x.toString();
      }

      final channelIndex = touchedSpots.indexOf(touchedSpot);
      final channelName = plotWidget.plotChannels.keys.toList()[channelIndex];
      final min =
          plotWidget.plotChannels[channelName]?.finalMinY ??
          plotWidget.plotData.minY ??
          0;
      final max =
          plotWidget.plotChannels[channelName]?.finalMaxY ??
          plotWidget.plotData.maxY ??
          1;
      final yValue = _scaleY(y, min: min, max: max);

      tooltips.add(
        LineTooltipItem('$xString, ${yValue.toStringAsFixed(2)}', textStyle),
      );
    }

    return tooltips;
  }

  double _scaleY(
    double yNormalized, {
    required double min,
    required double max,
  }) {
    final ySpan = max - min;
    return (yNormalized * ySpan + min);
  }

  List<LineChartBarData> _toLineChartBarDataList(
    List<PlotChannelData> plotChannels,
    PlotData plotData,
  ) {
    List<LineChartBarData> lineChartList = [];

    var points = plotData.points;

    // Timed X axis and no xMax defined will exit upon last out of range value.
    bool exitForScalar = plotWidget.confMaxX == null && plotWidget.isTimedXAxis;
    var cache = plotWidget.plotData.flchartCache;
    var arrayNonPersistentData =
        (!plotWidget.isTimedScalarData && !plotWidget.isPersistent);

    var arrayPersistentData =
        (!plotWidget.isTimedScalarData && plotWidget.isPersistent);

    plotChannels.asMap().forEach((index, plotChannel) {
      if (_channelHasError(plotChannel) ||
          !points.containsKey(plotChannel.name)) {
        return;
      }

      int nearestSegmentIndex = points[plotChannel.name]!.length - 1;
      if (arrayNonPersistentData || arrayPersistentData) {
        // Array data
        var selectedTime = plotData.selectedArrayTime;
        if (selectedTime != null) {
          // Find the segment index nearest to selectedArrayTime
          double minTimeDiff = double.infinity;

          for (var (idx, segment) in points[plotChannel.name]!.indexed) {
            var t = segment.first.t;
            if (t != null) {
              var timeDiff = (t - selectedTime).abs();
              if (timeDiff < minTimeDiff) {
                minTimeDiff = timeDiff;
                nearestSegmentIndex = idx;
              }
            }
          }
        }
      }

      for (var (segmentIndex, pointSegment)
          in points[plotChannel.name]!.indexed) {
        if (arrayNonPersistentData) {
          // Array data
          if (nearestSegmentIndex != segmentIndex) {
            continue;
          }

          plotWidget.plotMetadata.displayedArrayTime = pointSegment.first.t;
        }

        if (arrayPersistentData) {
          if (nearestSegmentIndex < segmentIndex) {
            // All done, index is larger
            break;
          }

          plotWidget.plotMetadata.displayedArrayTime = pointSegment.first.t;
        }

        if (arrayPersistentData) {
          if (nearestSegmentIndex < segmentIndex) {
            // All done, index is larger
            break;
          }

          plotWidget.plotMetadata.displayedArrayTime = pointSegment.first.t;
        }

        // min and max y is not passed in for limiting points. This can cause behavior where poitns in the middle of axis are dropped.
        var spots = cache.toSpots(
          points: pointSegment,
          channelName: plotChannel.name,
          channelSetting: plotWidget.plotChannels[plotChannel.name]!,
          segmentIndex: segmentIndex,
          minX: plotWidget.confMinX,
          maxX: plotWidget.confMaxX,
          exitForScalar: exitForScalar,
          appendExistingArrayPoints:
              arrayNonPersistentData || arrayPersistentData,
        );

        lineChartList.add(
          LineChartBarData(
            color: lineColorForChannel(plotChannel.name),
            spots: spots,
            isCurved: false,
            belowBarData: BarAreaData(show: false),
            barWidth:
                markerIndexForChannel(plotChannel.name) == 0 ||
                    markerIndexForChannel(plotChannel.name) == 1
                ? 3
                : 0,
            //dotData: _selectFlDotData(int.parse(widget.plotMarker.markerIndex)  , lineColorForChannel(plotChannel.name)),
            dotData: _selectFlDotData(
              markerIndexForChannel(plotChannel.name),
              lineColorForChannel(plotChannel.name),
            ),
          ),
        );

        if (arrayNonPersistentData) {
          // Array data
          break;
        }
      }
    });

    // Verify if points reduction should be performed.
    int? reducedPoints = cache.reduceSpots();
    cache.normalizeCacheSpots(
      channels: plotWidget.plotChannels,
      minY: plotWidget.plotData.minY,
      maxY: plotWidget.plotData.maxY,
    );

    plotWidget.plotMetadata.reducedPoints = reducedPoints;
    plotWidget.plotMetadata.numberOfPoints = cache.totalPoints;

    return lineChartList;
  }

  double _calculateYAxisLabelInterval({required int forNChannels}) {
    if (forNChannels < 3) {
      return 0.05;
    } else if (forNChannels < 5) {
      return 0.1;
    } else if (forNChannels < 7) {
      return 0.2;
    } else {
      return 0.25;
    }
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
