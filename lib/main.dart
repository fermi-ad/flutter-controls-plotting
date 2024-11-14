import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
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
  Widget build(BuildContext context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(children: [_buildWaveformPlot(context)])
          ]);

  Widget _buildWaveformPlot(BuildContext context) => Expanded(
      child: Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const SizedBox(
              height: 400,
              child: PlotWidget(plotChannels: ["PLOT TEST PARABOLA"]))));
}
