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
/// Each entry in [devices] defines one stable category on the X axis. Named
/// segments are rendered as independent bars by default, or as signed stacks
/// when the controller's style uses [BarChartLayout.stacked]. Streamed replies
/// update the segment keyed `value` with the label `Value`; other segments can
/// be supplied through [controller]. This widget has no notion of
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
  ///
  /// Use distinct names matching the channel names returned by [daqService].
  /// An empty list shows a placeholder and does not start acquisition. With an
  /// external [controller], this list should match its fixed device order.
  final List<String> devices;

  /// Service that supplies the streamed device readings.
  ///
  /// Acquisition starts after inherited dependencies are available. The widget
  /// cancels its subscription when disposed, but does not dispose this service.
  /// Replacing the service restarts acquisition only for an owned controller.
  final PlotDAQService daqService;

  /// Optional controller for updating segments and observing the latest state.
  ///
  /// When supplied, [style] and [colorForDevice] are ignored: the controller
  /// owns the style and color resolution set at its construction. The caller
  /// remains responsible for disposing an external controller.
  ///
  /// When omitted, the widget creates and disposes its own controller.
  /// Changing [devices] or [daqService] then recreates that controller and
  /// restarts acquisition, discarding the previous chart state. With an
  /// external controller, replace [controller] to restart acquisition or
  /// change its fixed device set; changing [devices] alone is unsupported.
  final BarChartController? controller;

  /// DAQ settings forwarded to [PlotDAQService.retrievePlot].
  ///
  /// Changing these settings alone does not restart an active subscription.
  /// They take effect the next time acquisition starts.
  final BarAcquisitionOptions acquisition;

  /// Renderer-neutral presentation settings for an owned controller.
  ///
  /// Ignored when [controller] is supplied. Changing these settings alone does
  /// not update an existing controller; they apply when it is next created.
  final BarChartStyle style;

  /// Resolves the color for a device's streamed segment.
  ///
  /// Falls back to [BarChartStyle.defaultColor] when omitted and is ignored
  /// when [controller] is supplied. The resolver is captured when an owned
  /// controller is created; changing it alone does not update that controller.
  final Color Function(String device)? colorForDevice;

  /// Called synchronously whenever the attached controller notifies listeners.
  ///
  /// Receives its latest immutable snapshot after a reply, segment update, or
  /// clear operation, including operations that leave values unchanged. It is
  /// not called just for attaching a controller or rebuilding the widget.
  final void Function(BarChartModel data)? onDataChanged;

  /// Called when starting acquisition throws or the stream emits an error.
  ///
  /// Existing chart data remains visible; an error placeholder is shown only
  /// when there are no segments. A subsequent reply clears the stream error.
  /// Per-channel negative statuses are recorded in [BarChartModel.errorsByDevice]
  /// instead and do not invoke this callback. Exceptions thrown by controller
  /// updates or [onDataChanged] are not routed through this callback.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Creates a stream-driven chart with an optional externally owned controller.
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
