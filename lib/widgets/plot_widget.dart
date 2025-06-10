import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/plot_metadata.dart';
import 'package:flutter_controls_plotting/entities/plot_stream_metadata.dart';
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
  final bool isPersistent;
  final ScalarDataOptions? scalarDataOptions;

  final Function(String channelName)? onInternalChannelSettingChange;

  final Function(PlotReply update)? onPlotUpdate;

  final Function(ConnectionState streamConnectionState)?
      onStreamConnectionStateChange;

  final PlotImplementation implementation;

  final Function(double scaleFactor, String event)? onZoom;

  final Function(double deltaX)? adjustXAxisLimits;

  final Function(double deltaY)? adjustYAxisLimits;

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
      this.isPersistent = false,
      this.scalarDataOptions,
      this.onInternalChannelSettingChange,
      this.onPlotUpdate,
      this.onStreamConnectionStateChange,
      this.onZoom,
      this.adjustXAxisLimits,
      this.adjustYAxisLimits,
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

  Duration get plotAnimationDuration {
    if (isTimedScalarData) {
      // No animation for scrolling data.
      return isTimedXAxis ? Duration.zero : const Duration(milliseconds: 150);
    }

    // No animation for frequency over 15Hz.
    if (updateDelay < 66666) {
      return Duration.zero;
    }

    // 50ms for frequency over 1Hz. 150 for 1Hz or slower.
    int animationMs = updateDelay < 1000000 ? 50 : 150;
    return Duration(milliseconds: animationMs);
  }

  PlotMetadata get plotMetadata => plotData.plotMetadata;
}

class PlotState extends State<PlotWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

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

  double? get minY => widget.plotData.minY;

  double? get maxY => widget.plotData.maxY;

  double? get minX => widget.plotData.minX;

  double? get maxX => widget.plotData.maxX;

  String get xAxisTitle => _plotReply != null ? _plotReply!.xAxisUnits : "";

  List<Color> get channelColors => widget.plotChannels.keys
      .map((String channelName) => _adapter.lineColorForChannel(channelName))
      .toList();

  List<int> get markerIndices => widget.plotChannels.keys
      .map((String channelName) => _adapter.markerIndexForChannel(channelName))
      .toList();

  Map<String, List<List<PlotPoint>>> get points => widget.plotData.points;
  PlotMetadata get plotMetadata => widget.plotMetadata;

  @override
  void didChangeDependencies() {
    _resetAdapter();
    _initializeStream();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PlotWidget oldWidget) {
    _resetAdapter();

    if (_streamShouldReset) {
      _initializeStream();
    } else if (_plotStreamMetadata.plotReply != null) {
      // Simulate last plot reply to reload plot data with potntially new configuration.
      // This mimics the behavior of stream builder.
      _receiveData(_plotStreamMetadata.plotReply!);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plotChannels.isEmpty) {
      _updateStreamConnectionChanged(ConnectionState.none);
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 30, 10),
        child: _buildEmptyPlot(),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          // "+" is the shifted version of "=" for some keyboard layouts.
          if (event.logicalKey == LogicalKeyboardKey.equal ||
              event.logicalKey == LogicalKeyboardKey.add) {
            widget.onZoom!(1.1, "key");
          } else if (event.logicalKey == LogicalKeyboardKey.minus) {
            widget.onZoom!(0.9, "key");
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.adjustYAxisLimits!(-10.0); // Pan up
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.adjustYAxisLimits!(10.0); // Pan down
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.adjustXAxisLimits!(10.0); // Pan left
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.adjustXAxisLimits!(-10.0); // Pan right
          }
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy > 0) {
              widget.onZoom!(0.9, "scroll"); // Zoom out
            } else {
              widget.onZoom!(1.1, "scroll"); // Zoom in
            }
          }
        },
        onPointerMove: (event) {
          widget.adjustXAxisLimits!(event.delta.dx);
          widget.adjustYAxisLimits!(-1 * event.delta.dy);
        },
        child: ListenableBuilder(
            listenable: _plotStreamMetadata, builder: _plotListenableBuilder),
      ),
    );
  }

  Widget _plotListenableBuilder(BuildContext context, Widget? child) {
    if (widget.plotChannels.isNotEmpty && _plotReply == null) {
      return _buildEmptyPlotWithProgressIndicator();
    }
    if (_plotStream != null) {
      if (_plotStreamMetadata.lastStreamError != null) {
        var error = _plotStreamMetadata.lastStreamError;
        _plotStreamMetadata.lastStreamError = null;
        return _buildWithErrorMessage(error!.toString(),
            child: _buildEmptyPlot());
      }
      final errorOnChannel = _plotReplyHasErrors();
      if (errorOnChannel != null) {
        return _buildWithErrorMessage(
            "An error occured when attempting to acquire data for $errorOnChannel",
            child: _buildPlotFromSnapshot());
      }

      if (_plotReply == null) {
        return _buildEmptyPlot();
      }

      return _buildPlotFromSnapshot();
    }

    return _buildEmptyPlot();
  }

  void _initializeStream() {
    _resetStream();
    _plotStreamSubscription?.cancel();
    _plotReply = null;

    if (widget.plotChannels.isNotEmpty) {
      _updateStreamConnectionChanged(ConnectionState.waiting);

      _plotStreamSubscription = _plotStream!.listen((plotReply) {
        _updateStreamConnectionChanged(ConnectionState.active);
        _receiveData(plotReply);
      }, onError: (error) {
        _plotStreamMetadata.lastStreamError = error;
        _plotReply = null;
      }, onDone: () {
        _updateStreamConnectionChanged(ConnectionState.done);
      });
    } else {
      _plotStream = null;
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
            isShowLabels: widget.isShowLabels,
            plotReply: _plotStreamMetadata.plotReply);
        break;

      case PlotImplementation.graphic:
        _adapter = GraphicPlotWidgetAdapter(
            widget: widget, plotReply: _plotStreamMetadata.plotReply);
        break;

      case PlotImplementation.fermi:
        _adapter = FermiPlotWidgetAdapter(
            widget: widget, plotReply: _plotStreamMetadata.plotReply);
        break;
    }
  }

  void _resetStream() {
    _plotReply = null;

    _channels = Map.from(widget.plotChannels);
    _updateDelay = widget.updateDelay;
    _triggerEvent = widget.triggerEvent;
    _nAcquisitions = widget.nAcquisitions;

    _updateStreamConnectionChanged(ConnectionState.none);

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
        _plotReply = lastReply;

        _filterPoints();

        _findLimits();

        widget.onPlotUpdate?.call(lastReply!);
      }

      plotReplyList.add(plotReply);
      if (plotReplyList.length > 1000000) {
        plotReplyList.removeAt(0);
      }
      return;
    } else {
      for (final element in plotReplyList) {
        _plotReply = element;

        _filterPoints();

        _findLimits();

        widget.onPlotUpdate?.call(element); // Use null check here
      }
      plotReplyList.clear();
    }

    lastReply = plotReply;

    if (widget.plotData.points.isEmpty) {
      // Switching from empty plot to plot with channels.
      // Ensure that min and max xy get adjusted appropriately.
      widget.plotData.resetMinMaxXY();
    }

    widget.plotData.processPlotReplyMetadata(plotReply: plotReply);
    _plotReply = plotReply;

    _filterPoints();

    _findLimits();

    widget.onPlotUpdate?.call(plotReply);
  }

  void _findLimits() {
    if (_plotReply == null) {
      return;
    }

    final plotChannels = _plotReply!.data;

    widget.plotData.findLimits(
        plotChannels: plotChannels,
        confMinY: widget.yMin,
        confMaxY: widget.yMax,
        confMinX: widget.xMin,
        confMaxX: widget.xMax,
        timeDelta: widget.scalarDataOptions?.timeDelta);
  }

  void _filterPoints() {
    if (_plotReply == null) {
      return;
    }

    // Verify if plotReply still needs to be processed.
    // Streambuilder by design seems to resend last plot reply on each update.
    if (!widget.plotData.isPlotReplyValid(_plotReply!)) {
      return;
    }

    final plotChannels = _plotReply!.data;
    widget.plotData.filterPoints(
        isTimedScalarData: widget.isTimedScalarData,
        isPersistent: widget.isPersistent,
        plotChannels: plotChannels);
  }

  String? _plotReplyHasErrors() {
    if (_plotReply != null) {
      for (PlotChannelData chData in _plotReply!.data as List) {
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

  final PlotStreamMetadata _plotStreamMetadata = PlotStreamMetadata();

  PlotReply? get _plotReply => _plotStreamMetadata.plotReply;

  set _plotReply(PlotReply? plotReply) {
    _plotStreamMetadata.plotReply = plotReply;
    _adapter.plotReply = plotReply;
  }

  StreamSubscription<PlotReply>? _plotStreamSubscription;

  Stream<PlotReply>? _plotStream;

  Map<String, ChannelSetting> _channels = {};

  ConnectionState? get lastConnectionState =>
      _plotStreamMetadata.lastConnectionState;

  set lastConnectionState(ConnectionState? state) {
    _plotStreamMetadata.lastConnectionState = state;
  }

  int _updateDelay = 0;

  int? _triggerEvent = 0;

  int _nAcquisitions = 0;

  bool _errorsDismissed = false;

  PlotReply? lastReply;

  List<PlotReply> plotReplyList = [];
}
