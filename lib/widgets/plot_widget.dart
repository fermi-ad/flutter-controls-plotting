import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget_adapter.dart';

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

enum PlotMarker {
  zero("Line", "0"),
  one("Line Dot", "1"),
  two("Dots", "2"),
  three("Circles", "3"),
  four("Cross", "4"),
  five("Square", "5"),
  six("OOOOOO", "6"),
  seven("KKKKKK", "7"),
  eight("VVVVVV", "8"),
  nine("Icon heart", "9"),
  ten("Icon arrow", "10"),
  eleven("Icon star", "11"),
  twelve("Icon Triangle", "12");

  const PlotMarker(this.name, this.markerIndex); // Ensure this line is correct
  final String name;
  final String markerIndex; // Ensure this line is correct
}

class ChannelSetting {
  Color? lineColor;
  PlotMarker? plotMarker;

  ChannelSetting({this.lineColor, this.plotMarker});

  // Clone functionality.
  static ChannelSetting from(ChannelSetting setting) {
    var newChannelSetting = ChannelSetting(
        lineColor: setting.lineColor, plotMarker: setting.plotMarker);
    return newChannelSetting;
  }
}

class PlotWidget extends StatefulWidget {
  final Map<String, ChannelSetting> plotChannels;

  final PlotDAQService daqService;

  final double? yMin;
  final double? yMax;
  final double? xMin;
  final double? xMax;

  final int updateDelay;

  final int? triggerEvent;

  final int nAcquisitions;

  final bool isShowLabels;

  final Function(String channelName)? onInternalChannelSettingChange;

  final PlotImplementation implementation;

  const PlotWidget(
      {super.key,
      this.plotChannels = const <String, ChannelSetting>{},
      this.daqService = const StandardPlotDAQ(),
      this.yMin,
      this.yMax,
      this.xMin,
      this.xMax,
      this.updateDelay = 0,
      this.nAcquisitions = 0,
      this.triggerEvent,
      this.isShowLabels = true,
      this.onInternalChannelSettingChange,
      this.implementation = PlotImplementation.flCharts});

  @override
  State<StatefulWidget> createState() => PlotState();
}

class PlotState extends State<PlotWidget> {
  List<PlotChannelData> get channelData =>
      _adapter.plotReply != null ? _adapter.plotReply!.data : [];

  List<String> get channelNames => _adapter.plotReply != null
      ? _adapter.plotReply!.data
          .map((PlotChannelData channelData) => channelData.name)
          .toList()
      : [];

  List<String> get channelUnits => _adapter.plotReply != null
      ? _adapter.plotReply!.data
          .map((PlotChannelData channelData) => channelData.units)
          .toList()
      : [];

  double get minY => _adapter.minY;

  double get maxY => _adapter.maxY;

  double get minX => _adapter.minX;

  double get maxX => _adapter.maxX;

  String get xAxisTitle =>
      _adapter.plotReply != null ? _adapter.plotReply!.xAxisUnits : "";

  List<Color> get channelColors => widget.plotChannels.keys
      .map((String channelName) => _adapter.lineColorForChannel(channelName))
      .toList();

  List<String> get markerIndices => widget.plotChannels.keys
      .map((String channelName) => _adapter.markerIndexForChannel(channelName))
      .toList();

  Map<String, List<PlotPoint>> get points => _adapter.plotReply != null
      ? Map.fromEntries(_adapter.plotReply!.data
          .map((PlotChannelData channelData) =>
              MapEntry(channelData.name, channelData.points))
          .toList())
      : {};

  @override
  void didChangeDependencies() {
    _resetAdapter();
    _resetStream();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PlotWidget oldWidget) {
    _resetAdapter();

    if (_streamShouldReset) {
      _resetStream();
    }
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
      _adapter.plotReply = null;
      return _buildEmptyPlotWithProgressIndicator();
    } else if (snapshot.hasError) {
      _adapter.plotReply = null;
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
      _adapter.plotReply = null;
      return _buildEmptyPlot();
    }
  }

  Widget _buildPlotFromSnapshot() => Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
      child: _adapter.buildPlot());

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

  Widget _buildEmptyPlot() => _adapter.buildPlot();

  void _handleDismissErrors() {
    setState(() => _errorsDismissed = true);
  }

  void _resetAdapter() {
    switch (widget.implementation) {
      case PlotImplementation.flCharts:
        _adapter = FlchartsPlotWidgetAdapter(
            widget: widget,
            isShowLabels: widget.isShowLabels); // Update this line
        break;

      case PlotImplementation.graphic:
        _adapter = GraphicPlotWidgetAdapter(widget: widget);
        break;

      case PlotImplementation.fermi:
        _adapter = FermiPlotWidgetAdapter(widget: widget);
        break;
    }
  }

  void _resetStream() {
    _adapter.plotReply = null;

    _channels = Map.from(widget.plotChannels);
    _updateDelay = widget.updateDelay;
    _triggerEvent = widget.triggerEvent;
    _nAcquisitions = widget.nAcquisitions;

    _channels = Map.from(widget.plotChannels);
    _updateDelay = widget.updateDelay;
    _triggerEvent = widget.triggerEvent;
    _nAcquisitions = widget.nAcquisitions;

    if (widget.plotChannels.isNotEmpty) {
      _errorsDismissed = false;

      _plotStream = widget.daqService.retrievePlot(context,
          forChannels: widget.plotChannels.keys.toSet(),
          updateDelay: widget.updateDelay,
          triggerEvent: widget.triggerEvent,
          nAcquisitions: widget.nAcquisitions);
    }
  }

  void _receiveData(PlotReply plotReply) {
    _adapter.plotReply = plotReply;

    _findLimits();

    _filterPoints();
  }

  void _findLimits() {
    final plotChannels = _adapter.plotReply!.data;
    for (var plotChannel in plotChannels) {
      if (_channelHasError(plotChannel)) {
        continue;
      }
      final points = plotChannel.points;
      for (final point in points) {
        _adapter.minY = min(point.y, _adapter.minY);
        _adapter.maxY = max(point.y, _adapter.maxY);
        _adapter.minX = min(point.x, _adapter.minX);
        _adapter.maxX = max(point.x, _adapter.maxX);
      }
    }

    if (widget.yMin != null) {
      _adapter.minY = widget.yMin!;
    }
    if (widget.yMax != null) {
      _adapter.maxY = widget.yMax!;
    }

    if (widget.xMin != null) {
      _adapter.minX = widget.xMin!;
    }
    if (widget.xMax != null) {
      _adapter.maxX = widget.xMax!;
    }
  }

  void _filterPoints() {
    _adapter.filteredPoints.clear();
    final plotChannels = _adapter.plotReply!.data;
    for (final plotChannel in plotChannels) {
      if (!_channelHasError(plotChannel)) {
        _adapter.filteredPoints[plotChannel.name] = plotChannel.points;
      }
    }
  }

  String? _plotReplyHasErrors() {
    if (_adapter.plotReply != null) {
      for (PlotChannelData chData in _adapter.plotReply!.data as List) {
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

  bool get _streamShouldReset => !((mapEquals(widget.plotChannels, _channels) &&
      _updateDelay == widget.updateDelay &&
      _nAcquisitions == widget.nAcquisitions &&
      _triggerEvent == widget.triggerEvent));

  late PlotWidgetAdapter _adapter;

  Stream<PlotReply>? _plotStream;

  Map<String, ChannelSetting> _channels = {};

  int _updateDelay = 0;

  int? _triggerEvent = 0;

  int _nAcquisitions = 0;

  bool _errorsDismissed = false;
}
