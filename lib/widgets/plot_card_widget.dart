import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';

class PlotCardWidget extends StatelessWidget {
  final PlotWidget plot;

  final String? title;

  const PlotCardWidget({super.key, required this.plot, this.title});

  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(children: [
        title == null ? Container() : Text(title!),
        SizedBox(
            height: 400,
            child: Padding(padding: const EdgeInsets.all(10), child: plot))
      ]));
}
