import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/bar_acquisition_options.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_controller.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_adapter.dart';
import 'package:flutter_controls_plotting/widgets/fl_chart_bar_adapter.dart';

/// Displays the latest streamed reading for each device as categorical bars.
///
/// Each entry in [devices] defines one stable category on the X axis. Each
/// device is rendered as a group of one or more independent bars — one per
/// named segment supplied through [controller]. This widget has no notion of
/// "reference" or "comparison" values; callers that want that behavior can
/// add named segments (e.g. `reading`, `setpoint`) via the controller and
/// style/label them accordingly.
///
/// The concrete charting library used to render the bars (currently
/// [`fl_chart`](https://pub.dev/packages/fl_chart)) is an internal
/// implementation detail behind [BarChartAdapter] and is not part of this
/// widget's public API.
class BarChartWidget extends StatefulWidget {
  /// Devices to request and display, in list order.
  final List<String> devices;

  /// Service that supplies the streamed device readings.
  final PlotDAQService daqService;

  /// Optional controller for adding/updating segments and observing
  /// externally the latest chart state. When supplied, [style] and
  /// [colorForDevice] are ignored — the controller owns its own style and
  /// color resolution, set when it was constructed.
  final BarChartController? controller;

  /// DAQ settings for the stream-driven chart.
  final BarAcquisitionOptions acquisition;

  /// Renderer-neutral presentation settings. Ignored when [controller] is
  /// supplied.
  final BarChartStyle style;

  /// Resolves the color for a device's streamed segment. Falls back to
  /// [BarChartStyle.defaultColor] when not supplied. Ignored when
  /// [controller] is supplied.
  final Color Function(String device)? colorForDevice;

  /// Called after the controller receives a new reply or segment update.
  final void Function(BarChartModel data)? onDataChanged;

  /// Called when acquisition or stream processing reports an error.
  final void Function(Object error, StackTrace stackTrace)? onError;

  const BarChartWidget({
    super.key,
    required this.devices,
    required this.daqService,
    this.controller,
    this.acquisition = const BarAcquisitionOptions(),
    this.style = const BarChartStyle(),
    this.colorForDevice,
    this.onDataChanged,
    this.onError,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  late BarChartController _controller;
  bool _ownsController = false;
  final BarChartAdapter _adapter = const FlChartBarAdapter();
  StreamSubscription? _subscription;
  Object? _error;
  bool _streamStarted = false;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // PlotDAQService implementations resolve ACSys from the inherited widget.
    // Start acquisition only after this State has completed initState and the
    // inherited provider is registered as a dependency.
    if (!_streamStarted) {
      _streamStarted = true;
      _startStream();
    }
  }

  @override
  void didUpdateWidget(BarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _subscription?.cancel();
      _detachController(oldWidget.controller);
      _createController();
      _startStream();
      return;
    }

    final devicesChanged = !listEquals(oldWidget.devices, widget.devices);
    if (devicesChanged || oldWidget.daqService != widget.daqService) {
      if (_ownsController) {
        _subscription?.cancel();
        _detachController(oldWidget.controller);
        _createController();
        _startStream();
      }
      // When an external controller is supplied, changing the device list
      // is unsupported: the controller's device set is fixed at
      // construction time. Recreate the controller externally if the
      // device list needs to change.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _detachController(widget.controller);
    super.dispose();
  }

  void _createController() {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        BarChartController(
          deviceNames: widget.devices,
          colorForDevice: widget.colorForDevice,
          style: widget.style,
        );
    _controller.addListener(_handleControllerChanged);
  }

  void _detachController(BarChartController? previous) {
    (previous ?? _controller).removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _handleControllerChanged() {
    widget.onDataChanged?.call(_controller.data);
  }

  void _startStream() {
    if (widget.devices.isEmpty) return;
    try {
      final stream = widget.daqService.retrievePlot(
        context,
        forChannels: widget.devices.toSet(),
        updateDelay: widget.acquisition.updateDelay,
        nAcquisitions: widget.acquisition.nAcquisitions,
        startTime: widget.acquisition.startTime,
        endTime: widget.acquisition.endTime,
        triggerEvent: widget.acquisition.triggerEvent,
        sampleOnEvent: widget.acquisition.sampleOnEvent,
      );
      _subscription = stream.listen(
        (reply) {
          _controller.applyReply(reply);
          if (!mounted) return;
          setState(() => _error = null);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() => _error = error);
          widget.onError?.call(error, stackTrace);
        },
      );
    } catch (error, stackTrace) {
      _error = error;
      widget.onError?.call(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) {
      return const Center(child: Text('No devices selected'));
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_error != null && _controller.data.segmentsByDevice.isEmpty) {
          return Center(
            child: Text('Unable to acquire device readings: $_error'),
          );
        }
        return _adapter.build(context, _controller.data);
      },
    );
  }
}
