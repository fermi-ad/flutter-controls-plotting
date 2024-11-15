import 'package:flutter/material.dart';

class PlotCardWidget extends StatelessWidget {
  final Widget child;

  const PlotCardWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SizedBox(
          height: 400,
          child: Padding(padding: const EdgeInsets.all(10), child: child)));
}
