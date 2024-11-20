import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/widgets/plot_card_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';

Future<void> main() async {
  await runFermiApp(appWidget: const App());
}

class App extends StatelessWidget {
  const App({super.key});

  static const _title = 'Plotting Widgets Demo';

  @override
  Widget build(BuildContext context) => ACSysProvider(
      child: StandardApp(
          title: _title,
          appBar: AppBar(title: const Text(_title)),
          body: _BaseWidget()));
}

class _BaseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildEmptyPlot(),
            _buildWaveformPlot(),
            _buildMultipleWaveformPlot()
          ]));

  Widget _buildEmptyPlot() =>
      const Expanded(child: PlotCardWidget(child: PlotWidget()));

  Widget _buildWaveformPlot() => const Expanded(
      child: PlotCardWidget(
          child: PlotWidget(plotChannels: {"PLOT TEST PARABOLA"})));

  Widget _buildMultipleWaveformPlot() => const Expanded(
      child: PlotCardWidget(
          child: PlotWidget(
              plotChannels: {"PLOT TEST RAND RAMP", "PLOT TEST NORMAL"})));
}
