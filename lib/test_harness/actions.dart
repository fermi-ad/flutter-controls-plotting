import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  bool timerDone = false;
  final timer = Timer(timeout, () => timerDone = true);
  while (timerDone != true) {
    await tester.pumpAndSettle();

    final found = tester.any(finder);
    if (!found) {
      timerDone = true;
    }
  }
  timer.cancel();
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  bool timerDone = false;
  final timer = Timer(timeout, () => timerDone = true);
  while (timerDone != true) {
    await tester.pumpAndSettle();

    final found = tester.any(finder);
    if (found) {
      timerDone = true;
    }
  }
  timer.cancel();
}

Future<void> waitForPlotDataToLoad(WidgetTester tester) async {
  await pumpUntilGone(
    tester,
    find.descendant(
      of: find.byType(PlotWidget),
      matching: find.byType(LinearProgressIndicator),
    ),
  );
}
