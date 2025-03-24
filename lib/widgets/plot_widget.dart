import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/plot_metadata.dart';
import 'package:flutter_controls_plotting/entities/scalar_data_options.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget_adapter.dart';

enum PlotImplementation { flCharts, graphic, fermi }

class PlotWidget extends StatefulWidget {
  final Map<String, ChannelSetting> plotChannels;

  final PlotDAQService daqService;
  final PlotData plotData;

  final double? yMin;
  final double? yMax;
  final double? xMin;
  final double? xMax;

  final int updateDelay;

  final int? triggerEvent;

  final int nAcquisitions;

  final bool isShowLabels;
  final bool isPaused;
  final ScalarDataOptions? scalarDataOptions;

  final Function(String channelName)? onInternalChannelSettingChange;

  final Function(PlotReply update)? onPlotUpdate;

  final Function(ConnectionState streamConnectionState)?
      onStreamConnectionStateChange;

  final PlotImplementation implementation;

  final Function(double deltaX)? adjustXAxisLimits;

  const PlotWidget(
      {super.key,
      this.plotChannels = const <String, ChannelSetting>{},
      required this.daqService,
      required this.plotData,
      this.yMin,
      this.yMax,
      this.xMin,
      this.xMax,
      this.updateDelay = 0,
      this.nAcquisitions = 0,
      this.triggerEvent,
      this.isShowLabels = true,
      this.isPaused = false,
      this.scalarDataOptions,
      this.onInternalChannelSettingChange,
      this.onPlotUpdate,
      this.onStreamConnectionStateChange,
      this.adjustXAxisLimits,
      this.implementation = PlotImplementation.flCharts});

  @override
  State<StatefulWidget> createState() => PlotState();

  bool get isTimedScalarData => scalarDataOptions != null;
  bool get isTimedXAxis {
    if (isTimedScalarData) {
      return triggerEvent == null;
    }
    return false;
  }
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

  double? get minY => widget.plotData.minY;

  double? get maxY => widget.plotData.maxY;

  double? get minX => widget.plotData.minX;

  double? get maxX => widget.plotData.maxX;

  String get xAxisTitle =>
      _adapter.plotReply != null ? _adapter.plotReply!.xAxisUnits : "";

  List<Color> get channelColors => widget.plotChannels.keys
      .map((String channelName) => _adapter.lineColorForChannel(channelName))
      .toList();

  List<int> get markerIndices => widget.plotChannels.keys
      .map((String channelName) => _adapter.markerIndexForChannel(channelName))
      .toList();

  Map<String, List<List<PlotPoint>>> get points => widget.plotData.points;
  PlotMetadata get plotMetadata => widget.plotData.plotMetadata;

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
  Widget build(BuildContext context) {
    if (widget.plotChannels.isEmpty) {
      _updateStreamConnectionChanged(ConnectionState.none);
      return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
          child: _buildEmptyPlot());
    }
    return Listener(
      onPointerMove: (event) {
        widget.adjustXAxisLimits!(event.delta.dx);
      },
      child: StreamBuilder(
        stream: _plotStream,
        builder: _plotStreamBuilder,
      ),
    );
  }

  Widget _plotStreamBuilder(
      BuildContext context, AsyncSnapshot<PlotReply> snapshot) {
    _updateStreamConnectionChanged(snapshot.connectionState);

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

  Widget _buildEmptyPlot() {
    return _adapter.buildPlot();
  }

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

    // Widget is displaying scalar data in one-shot mode.
    if (widget.scalarDataOptions != null) {
      if (widget.scalarDataOptions!.isOneShot &&
          widget.scalarDataOptions!.timeDelta != null &&
          widget.updateDelay > 0) {
        // Using calculated nAcquisitions
        var timeDelta = widget.scalarDataOptions!.timeDelta;
        // Number of points per second
        double pointLimitCalc = 1000000 / widget.updateDelay;
        // Number of seconds
        pointLimitCalc = pointLimitCalc * timeDelta!;
        // Round up to ensure number of acquisitions include full timeframe.
        _nAcquisitions = pointLimitCalc.ceil();
      }
    }

    widget.plotData.scalarEventMode =
        widget.isTimedScalarData && !widget.isTimedXAxis;

    if (widget.plotChannels.isNotEmpty) {
      _errorsDismissed = false;

      _plotStream = widget.daqService.retrievePlot(context,
          forChannels: _channels.keys.toSet(),
          updateDelay: _updateDelay,
          triggerEvent: _triggerEvent,
          nAcquisitions: _nAcquisitions);
    }
  }

  void _receiveData(PlotReply plotReply) {
    if (widget.isPaused) {
      if (lastReply != null) {
        _adapter.plotReply = lastReply;

        _filterPoints();

        _findLimits();

        widget.onPlotUpdate?.call(lastReply!);
      }
      return;
    }

    lastReply = plotReply;

    if (widget.plotData.points.isEmpty) {
      // Switching from empty plot to plot with channels.
      // Ensure that min and max xy get adjusted appropriately.
      widget.plotData.resetMinMaxXY();
    }

    widget.plotData.processPlotReplyMetadata(plotReply: plotReply);
    _adapter.plotReply = plotReply;

    _filterPoints();

    _findLimits();

    widget.onPlotUpdate?.call(plotReply);
  }

  void _findLimits() {
    if (_adapter.plotReply == null) {
      return;
    }

    final plotChannels = _adapter.plotReply!.data;

    widget.plotData.findLimits(
        plotChannels: plotChannels,
        confMinY: widget.yMin,
        confMaxY: widget.yMax,
        confMinX: widget.xMin,
        confMaxX: widget.xMax,
        timeDelta: widget.scalarDataOptions?.timeDelta);
  }

  void _filterPoints() {
    if (_adapter.plotReply == null) {
      return;
    }

    final plotChannels = _adapter.plotReply!.data;
    widget.plotData.filterPoints(
        isTimedScalarData: widget.isTimedScalarData,
        plotChannels: plotChannels);
  }

  String? _plotReplyHasErrors() {
    if (_adapter.plotReply != null) {
      for (PlotChannelData chData in _adapter.plotReply!.data as List) {
        if (channelHasError(chData)) {
          return chData.name;
        }
      }
    }

    return null;
  }

  void _updateStreamConnectionChanged(ConnectionState state) {
    if (widget.onStreamConnectionStateChange == null) {
      return;
    }

    if (lastConnectionState == null || lastConnectionState != state) {
      widget.onStreamConnectionStateChange?.call(state);
      lastConnectionState = state;
    }
  }

  bool get _streamShouldReset => !((mapEquals(widget.plotChannels, _channels) &&
      _updateDelay == widget.updateDelay &&
      _nAcquisitions == widget.nAcquisitions &&
      _triggerEvent == widget.triggerEvent));

  late PlotWidgetAdapter _adapter;

  Stream<PlotReply>? _plotStream;

  Map<String, ChannelSetting> _channels = {};

  ConnectionState? lastConnectionState;

  int _updateDelay = 0;

  int? _triggerEvent = 0;

  int _nAcquisitions = 0;

  bool _errorsDismissed = false;

  PlotReply? lastReply;
}
