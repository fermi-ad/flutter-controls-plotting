import 'package:flutter/material.dart';

class PlotWidgetErrorBanner extends StatelessWidget {
  final String message;
  final ColorScheme scheme;
  final VoidCallback? onPressed;
  const PlotWidgetErrorBanner({
    super.key,
    required this.message,
    required this.scheme,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      padding: const EdgeInsets.all(5),
      content: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      leading: const Icon(Icons.error),
      backgroundColor: scheme.errorContainer,
      actions: <Widget>[
        TextButton(
          onPressed: onPressed,
          child: Text(
            'Dismiss',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      ],
    );
  }
}
