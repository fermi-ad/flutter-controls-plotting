import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class ChannelSetting {  
  Color? lineColor; 

  ChannelSetting(); 
}

class PlotWidget extends StatefulWidget {
  final Map<String, ChannelSetting> plotChannels;  

  final PlotDAQService daqService;

  const PlotWidget(
      {super.key,
      this.plotChannels = const <String, ChannelSetting>{},
      this.daqService = const StandardPlotDAQ()});

  @override
  State<StatefulWidget> createState() => _PlotState();
}

class _PlotState extends State<PlotWidget> {
  @override
  void didChangeDependencies() {
    final channels = widget.plotChannels;
    if (channels.isNotEmpty) {
      _plotStream = widget.daqService
          .retrievePlot(context, forChannels: widget.plotChannels.keys.toSet());
    }

    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channels = widget.plotChannels;
    if (channels.isNotEmpty) {
      // Reset for new plot.
      _errorsDismissed = false;
      _plotStream = widget.daqService
          .retrievePlot(context, forChannels: widget.plotChannels.keys.toSet());
    }
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
      return _buildEmptyPlotWithProgressIndicator();
    } else if (snapshot.hasError) {
      return _buildWithErrorMessage(snapshot.error!.toString(),
          child: _buildEmptyPlot());
    } else if (snapshot.hasData) {
      final errorOnChannel = _checkSnapshotDataForErrors(snapshot);
      return errorOnChannel != null
          ? _buildWithErrorMessage(
              "An error occured when attempting to acquire data for $errorOnChannel",
              child: _buildPlotFromSnapshot(snapshot))
          : _buildPlotFromSnapshot(snapshot);
    } else {
      return _buildEmptyPlot();
    }
  }

  Widget _buildPlotFromSnapshot(AsyncSnapshot<PlotReply> snapshot) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
      child: _buildPlot(plotReply: snapshot.data!));

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

  Widget _buildEmptyPlot() => _buildPlot(plotReply: null);

  Widget _buildPlot({required PlotReply? plotReply}) {
    List<LineChartBarData> lineChartBarDataList;

    if (plotReply != null) {
      lineChartBarDataList = _toLineChartBarDataList(plotReply.data);
    } else {
      // Defaults
      lineChartBarDataList = [];
    }

    final (minX, minY, maxX, maxY) =
        _findLimits(lineChartBarDataList: lineChartBarDataList);

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            LineChart(LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
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
              titlesData:
                  _buildTitlesData(plotReply, wide: constraints.maxWidth > 600),
            )));
  }

  FlTitlesData _buildTitlesData(PlotReply? plotReply, {required bool wide}) {
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

    for (var (index, channelData) in plotReply.data.indexed) {
      if (_channelHasError(channelData)) {
        continue;
      }
      rowDataContents
          .add(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          channelData.name,
          style: TextStyle(color: _nextColorForIndex(index)),
        ),
        Text(
          " (${channelData.units})",
          style: TextStyle(color: _nextColorForIndex(index)),
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

  void _handleDismissErrors() {
    setState(() => _errorsDismissed = true);
  }

  (double, double, double, double) _findLimits(
      {required List<LineChartBarData> lineChartBarDataList}) {
    double minY = 0.0;
    double maxY = 1.0;
    double minX = 0.0;
    double maxX = 1.0;

    for (final plotData in lineChartBarDataList) {
      var spots = plotData.spots;
      for (final spot in spots) {
        minY = min(spot.y, minY);
        maxY = max(spot.y, maxY);
        minX = min(spot.x, minX);
        maxX = max(spot.x, maxX);
      }
    }

    return (minX, minY, maxX, maxY);
  }

  Color _nextColorForIndex(int index) {
    var colorIndex = min(index, Colors.primaries.length);
    return Colors.primaries[colorIndex];
  }

  List<LineChartBarData> _toLineChartBarDataList(
      List<PlotChannelData> plotChannels) {
    List<LineChartBarData> lineChartList = [];

    for (var (index, plotChannel) in plotChannels.indexed) {
      if (_channelHasError(plotChannel)) {
        continue;
      }

      var spots = _toSpots(plotChannel.points);

      lineChartList.add(LineChartBarData(
        color: _nextColorForIndex(index),
        spots: spots,
        isCurved: true,
        isStrokeCapRound: true,
        barWidth: 3,
        belowBarData: BarAreaData(
          show: false,
        ),
        dotData: const FlDotData(show: false),
      ));
    }

    return lineChartList;
  }

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  bool _errorsDismissed = false;

  Stream<PlotReply>? _plotStream;

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
}
