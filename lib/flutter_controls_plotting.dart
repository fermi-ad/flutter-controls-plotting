/// Public API for the Flutter Controls plotting package.
///
/// Import this library instead of importing individual entity and widget files:
///
/// ```dart
/// import 'package:flutter_controls_plotting/flutter_controls_plotting.dart';
/// ```
///
/// Renderer-specific adapters remain private implementation details so the
/// plotting library can change without requiring consumer changes.
library;

export 'entities/bar_acquisition_options.dart';
export 'entities/bar_chart_controller.dart';
export 'entities/bar_chart_model.dart';
export 'entities/bar_chart_style.dart';
export 'entities/bar_segment.dart';
export 'service/plot_daq_service.dart';
export 'widgets/bar_chart_widget.dart';
