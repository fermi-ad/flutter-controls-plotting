import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_metadata.dart';
import 'package:flutter_controls_plotting/entities/bar_acquisition_options.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_controller.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment_policy.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_adapter.dart';
import 'package:flutter_controls_plotting/widgets/fl_chart_bar_adapter.dart';

/// Displays the latest streamed reading for each device as categorical bars.
///
/// Each entry in [devices] defines one stable category on the X axis. The
/// latest valid reading for that device is rendered as its current bar value.
/// If a reference is supplied through [controller], the adapter renders one
/// stacked bar: the reference portion is neutral, a higher-than-reference
/// portion is red, and a lower-than-reference portion is green.
class BarChartWidget extends StatefulWidget {
  /// Devices to request and display, in map iteration order.
  final Map<String, ChannelMetadata> devices;

  /// Service that supplies the streamed device readings.
  final PlotDAQService daqService;

  /// Optional controller for references and externally observed chart state.
  final BarChartController? controller;

  /// DAQ settings for the stream-driven chart.
  final BarAcquisitionOptions acquisition;

  /// Renderer-neutral presentation settings, including segment colors.
  final BarChartStyle style;

  /// Converts named values into ordered visual segments.
  final BarSegmentPolicy segmentPolicy;

  /// Called after the controller receives a new reply or reference update.
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
    this.segmentPolicy = const ReferenceDeltaSegmentPolicy(),
    this.onDataChanged,
    this.onError,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  late BarChartController _controller;
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
    final devicesChanged =
        oldWidget.devices.keys.toList().toString() !=
        widget.devices.keys.toList().toString();
    if (devicesChanged || oldWidget.daqService != widget.daqService) {
      _subscription?.cancel();
      _createController();
      _startStream();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _createController() {
    _controller =
        widget.controller ??
        BarChartController(
          deviceNames: widget.devices.keys,
          colorForDevice: (device) =>
              widget.devices[device]!.channelSetting.lineColor ?? Colors.blue,
          segmentPolicy: widget.segmentPolicy,
          style: widget.style,
        );
  }

  void _startStream() {
    if (widget.devices.isEmpty) return;
    try {
      final stream = widget.daqService.retrievePlot(
        context,
        forChannels: widget.devices.keys.toSet(),
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
          widget.onDataChanged?.call(_controller.data);
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

  void setReference(String device, double value) {
    _controller.setReference(device: device, value: value);
    if (mounted) setState(() {});
    widget.onDataChanged?.call(_controller.data);
  }

  void clearReference({String? device}) {
    _controller.clearReference(device: device);
    if (mounted) setState(() {});
    widget.onDataChanged?.call(_controller.data);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) {
      return const Center(child: Text('No devices selected'));
    }
    if (_error != null && _controller.data.valuesByDevice.isEmpty) {
      return Center(child: Text('Unable to acquire device readings: $_error'));
    }
    return _adapter.build(context, _controller.data);
  }
}
