import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/demo_app/widgets/plot_demo_widget.dart';

Future<void> main() async {
  await runFermiApp(appWidget: const App());
}

class App extends StatelessWidget {
  const App({super.key});

  static const _title = 'Plotting Widgets Demo';

  @override
  Widget build(BuildContext context) => StandardApp(
    title: _title,
    appBar: AppBar(title: const Text(_title)),
    body: const PlotDemoWidget(),
  );
}
