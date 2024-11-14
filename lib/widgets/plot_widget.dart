import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_template/service/plot_daq_service.dart';

class PlotWidget extends StatefulWidget {
  final List<String> plotChannels;

  final PlotDAQService daqService;

  const PlotWidget(
      {super.key, required this.plotChannels, required this.daqService});

  @override
  State<StatefulWidget> createState() => _PlotState();
}

class _PlotState extends State<PlotWidget> {
  @override
  void didChangeDependencies() {
    final channels = widget.plotChannels;
    if (channels.isNotEmpty) {
      _plotStream = widget.daqService
          .retrievePlot(context, forChannel: widget.plotChannels.first);
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
          .retrievePlot(context, forChannel: widget.plotChannels.first);
    }
  }

  @override
  Widget build(BuildContext context) => widget.plotChannels.isEmpty
      ? Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 30, 0),
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
              child: _buildEmptyPlot())
          : _buildPlotFromSnapshot(snapshot);
    } else {
      return _buildEmptyPlot();
    }
  }

  Widget _buildPlotFromSnapshot(AsyncSnapshot<PlotReply> snapshot) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 30, 0),
      child: _buildPlot(
          channelNames: widget.plotChannels,
          channelUnits: [snapshot.data!.data.first.units],
          xAxisLabel: snapshot.data!.xAxisUnits,
          spots: _toSpots(snapshot.data!.data.first.points)));

  Widget _buildEmptyPlotWithProgressIndicator() => Column(children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: SizedBox(
                height: 40,
                child:
                    Column(children: [Spacer(), LinearProgressIndicator()]))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 30, 0),
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
      _buildPlot(channelNames: [], channelUnits: [], spots: [], xAxisLabel: "");

  Widget _buildPlot(
      {required List<String> channelNames,
      required List<String> channelUnits,
      required List<FlSpot> spots,
      required String xAxisLabel}) {
    final (minX, minY, maxX, maxY) = _findLimits(forPlotData: spots);

    return LineChart(LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          isStrokeCapRound: true,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: false,
          ),
          dotData: const FlDotData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          maxContentWidth: 100,
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
      titlesData: _buildTitlesData(channelNames, channelUnits, xAxisLabel),
    ));
  }

  FlTitlesData _buildTitlesData(
      List<String> channelNames, List<String> channelUnits, String xAxisLabel) {
    if (channelNames.isEmpty) {
      return const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );
    }

    final wide = MediaQuery.of(context).size.width > 600;

    const emptyTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

    final AxisTitles leftTitles;
    final AxisTitles topTitles;
    if (wide) {
      leftTitles = AxisTitles(
        axisNameSize: 20,
        axisNameWidget:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            channelNames.first,
            style: const TextStyle(),
          ),
          Text(" (${channelUnits.first})")
        ]),
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 40,
        ),
      );

      topTitles = emptyTitles;
    } else {
      leftTitles = const AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
        ),
      );

      topTitles = AxisTitles(
        axisNameSize: 50,
        axisNameWidget:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            channelNames.first,
            style: const TextStyle(),
          ),
          Text(" (${channelUnits.first})")
        ]),
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
      {required List<FlSpot> forPlotData}) {
    double minY = 0.0;
    double maxY = 1.0;
    double minX = 0.0;
    double maxX = 1.0;

    for (final spot in forPlotData) {
      if (spot.y < minY) {
        minY = spot.y;
      }
      if (spot.y > maxY) {
        maxY = spot.y;
      }
      if (spot.x < minX) {
        minX = spot.x;
      }
      if (spot.x > maxX) {
        maxX = spot.x;
      }
    }

    return (minX, minY, maxX, maxY);
  }

  List<FlSpot> _toSpots(List<PlotPoint> points) => points
      .map<FlSpot>((PlotPoint point) => FlSpot(point.x, point.y))
      .toList();

  bool _errorsDismissed = false;

  Stream<PlotReply>? _plotStream;

  _checkSnapshotDataForErrors(AsyncSnapshot<PlotReply> snapshot) {
    if (snapshot.data!.data.first.status < 0) {
      return snapshot.data!.data.first.name;
    } else {
      return null;
    }
  }
}
