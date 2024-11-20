import 'package:flutter/material.dart';

class PlotCardWidget extends StatelessWidget {
  final Widget child;

  final String? title;

  const PlotCardWidget({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(children: [
        title == null ? Container() : Text(title!),
        SizedBox(
            height: 400,
            child: Padding(padding: const EdgeInsets.all(10), child: child))
      ]));
}
