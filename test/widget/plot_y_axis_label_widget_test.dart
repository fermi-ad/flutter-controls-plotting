import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/test_harness/assertions.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotYAxisLabelWidget widget tests", () {
    testWidgets("No min/max given, normalized value is displayed",
        (WidgetTester tester) async {
      // Given a PlotYAxisLabelWidget with no min: or max: parameters
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 1
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: PlotYAxisLabelWidget(normalizedValue: 1.0))));

      // Then the normalized value is displayed
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "1.00");
    });

    testWidgets(
        "Min is 0 and max is positive, correct normalized value is displayed",
        (WidgetTester tester) async {
      // Given a PlotYAxisLabelWidget with min: 0 and max: 10
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 1
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PlotYAxisLabelWidget(
                  min: 0, max: 10, normalizedValue: 1.0))));

      // Then the display value is...
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "10.00");
    });
  });
}
