import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:graphic/graphic.dart';

enum PlotImplementation { flCharts, graphic, fermi }

// Defines a default set of colors for plots. It is possible to pass in any color as well.
enum PlotColor {
  red("Red", Colors.red),
  green("Green", Colors.green),
  blue("Blue", Colors.blue),
  yellow("Yellow", Colors.yellow),
  brown("Brown", Colors.brown),
  gray("Gray", Colors.blueGrey),
  purple("Purple", Colors.purple),
  lime("Lime", Colors.lime),
  cyan("Cyan", Colors.cyan),
  orange("Orange", Colors.orange);

  const PlotColor(this.name, this.color);
  final String name;
  final Color color;
}

class ChannelSetting {
  Color? lineColor;

  ChannelSetting({this.lineColor});
}

class PlotWidget extends StatefulWidget {
  final Map<String, ChannelSetting> plotChannels;

  final PlotDAQService daqService;

  final List<String> yLimits;

  final PlotImplementation implementation;

  const PlotWidget(
      {super.key,
      this.plotChannels = const <String, ChannelSetting>{},
      this.daqService = const StandardPlotDAQ(),
      this.yLimits = const ["", ""],
      this.implementation = PlotImplementation.flCharts});

  @override
  State<StatefulWidget> createState() => PlotState();
}

class PlotState extends State<PlotWidget> {
  List<PlotChannelData> get channelData =>
      _plotReply != null ? _plotReply!.data : [];

  List<String> get channelNames => _plotReply != null
      ? _plotReply!.data
          .map((PlotChannelData channelData) => channelData.name)
          .toList()
      : [];

  List<String> get channelUnits => _plotReply != null
      ? _plotReply!.data
          .map((PlotChannelData channelData) => channelData.units)
          .toList()
      : [];

  double get minY => _minY;

  double get maxY => _maxY;

  @override
  void didChangeDependencies() {
    _resetStream();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PlotWidget oldWidget) {
    _resetStream();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) => widget.plotChannels.isEmpty
      ? Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
          child: _buildEmptyPlot())
      : StreamBuilder(stream: _plotStream, builder: _plotStreamBuilder);

  Widget _plotStreamBuilder(
      BuildContext context, AsyncSnapshot<PlotReply> snapshot) {
    if (snapshot.connectionState == ConnectionState.none ||
        snapshot.connectionState == ConnectionState.waiting) {
      _plotReply = null;
      return _buildEmptyPlotWithProgressIndicator();
    } else if (snapshot.hasError) {
      _plotReply = null;
      return _buildWithErrorMessage(snapshot.error!.toString(),
          child: _buildEmptyPlot());
    } else if (snapshot.hasData) {
      final errorOnChannel = _checkSnapshotDataForErrors(snapshot);
      _plotReply = snapshot.data;
      return errorOnChannel != null
          ? _buildWithErrorMessage(
              "An error occured when attempting to acquire data for $errorOnChannel",
              child: _buildPlotFromSnapshot())
          : _buildPlotFromSnapshot();
    } else {
      _plotReply = null;
      return _buildEmptyPlot();
    }
  }

  Widget _buildPlotFromSnapshot() => Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
      child: widget.implementation == PlotImplementation.flCharts
          ? _buildFlChartsPlot(yLimits: widget.yLimits)
          : _buildGraphicPlot(yLimits: widget.yLimits));

  Widget _buildEmptyPlotWithProgressIndicator() => Column(children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: SizedBox(
                height: 40,
                child:
                    Column(children: [Spacer(), LinearProgressIndicator()]))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
                child: _buildEmptyPlot()))
      ]);

  Widget _buildWithErrorMessage(String message, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Visibility(
          visible: !_errorsDismissed,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              child: MaterialBanner(
                padding: const EdgeInsets.all(5),
                content: Text(message,
                    style: TextStyle(color: scheme.onErrorContainer)),
                leading: const Icon(Icons.error),
                backgroundColor: scheme.errorContainer,
                actions: <Widget>[
                  TextButton(
                    onPressed: _handleDismissErrors,
                    child: Text('Dismiss',
                        style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                ],
              ))),
      Expanded(child: child)
    ]);
  }

  Widget _buildEmptyPlot() =>
      widget.implementation == PlotImplementation.flCharts
          ? _buildFlChartsPlot(yLimits: [])
          : _buildGraphicPlot(yLimits: []);

  Widget _buildFlChartsPlot({required List<String> yLimits}) {
    List<LineChartBarData> lineChartBarDataList;
    double minX, minY, maxX, maxY;
    List<List<FlSpot>> filteredChannelSpots;

    if (_plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      (minX, minY, maxX, maxY, filteredChannelSpots) =
          _findLimits(plotChannels: _plotReply!.data, yLimits: yLimits);
      lineChartBarDataList =
          _toLineChartBarDataList(_plotReply!.data, filteredChannelSpots);
    } else {
      // Defaults
      lineChartBarDataList = [];
      (minX, minY, maxX, maxY) = (0.0, 0.0, 1.0, 1.0);
    }

    _minY = minY;
    _maxY = maxY;

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            LineChart(LineChartData(
              minX: minX,
              maxX: maxX,
              minY: _minY,
              maxY: _maxY,
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
              titlesData: _buildTitlesData(wide: constraints.maxWidth > 600),
            )));
  }

  Widget _buildGraphicPlot({required List<String> yLimits}) {
    double minX, minY, maxX, maxY;
    List<List<FlSpot>> filteredChannelSpots;

    if (_plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      (minX, minY, maxX, maxY, filteredChannelSpots) =
          _findLimits(plotChannels: _plotReply!.data, yLimits: yLimits);
    } else {
      // Defaults
      (minX, minY, maxX, maxY) = (0.0, 0.0, 1.0, 1.0);
    }

    _minY = minY;
    _maxY = maxY;

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

  FlTitlesData _buildTitlesData({required bool wide}) {
    // List<String> channelNames, List<String> channelUnits, String xAxisLabel) {
    if (_plotReply == null) {
      return const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );
    }

    final xAxisLabel = _plotReply!.xAxisUnits;

    const emptyTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

    final AxisTitles leftTitles;
    final AxisTitles topTitles;

    List<Row> rowDataContents = [];

    for (var channelData in _plotReply!.data) {
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

    double axisNameSize = _plotReply!.data.length * 20;
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

  void _handleDismissErrors() {
    setState(() => _errorsDismissed = true);
  }

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

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  void _resetStream() {
    _plotReply = null;

    if (widget.plotChannels.isNotEmpty) {
      _errorsDismissed = false;
      _plotStream = widget.daqService
          .retrievePlot(context, forChannels: widget.plotChannels.keys.toSet());
    }
  }

  _checkSnapshotDataForErrors(AsyncSnapshot<PlotReply> snapshot) {
    if (snapshot.data != null) {
      for (PlotChannelData chData in snapshot.data?.data as List) {
        if (_channelHasError(chData)) {
          return chData.name;
        }
      }
    }

    return null;
  }

  bool _channelHasError(PlotChannelData chData) {
    return chData.status < 0;
  }

  Stream<PlotReply>? _plotStream;

  PlotReply? _plotReply;

  double _minY = 0;

  double _maxY = 0;

  bool _errorsDismissed = false;
}
