import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/flcharts_plot_widget_adapter.dart';

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

  double get minY => _adapter.minY;

  double get maxY => _adapter.maxY;

  @override
  initState() {
    _adapter = FlchartsPlotWidgetAdapter(widget: widget);
    super.initState();
  }

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
      _receiveData(snapshot.data!);
      final errorOnChannel = _plotReplyHasErrors();
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
      child:
          _adapter.buildPlot(plotReply: _plotReply, yLimits: widget.yLimits));

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
      _adapter.buildPlot(plotReply: _plotReply, yLimits: []);

  void _handleDismissErrors() {
    setState(() => _errorsDismissed = true);
  }

  void _resetStream() {
    _plotReply = null;

    if (widget.plotChannels.isNotEmpty) {
      _errorsDismissed = false;
      _plotStream = widget.daqService
          .retrievePlot(context, forChannels: widget.plotChannels.keys.toSet());
    }
  }

  void _receiveData(PlotReply plotReply) {
    _plotReply = plotReply;
  }

  _plotReplyHasErrors() {
    if (_plotReply != null) {
      for (PlotChannelData chData in _plotReply!.data as List) {
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

  late PlotWidgetAdapter _adapter;

  Stream<PlotReply>? _plotStream;

  PlotReply? _plotReply;

  bool _errorsDismissed = false;
}
