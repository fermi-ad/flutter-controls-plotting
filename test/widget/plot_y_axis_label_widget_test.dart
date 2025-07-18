import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/test_harness/assertions.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotYAxisLabelWidget widget tests", () {
    testWidgets("No min/max given, normalized value is displayed",
        (WidgetTester tester) async {
      // Given a PlotYAxisLabelWidget with no min: or max: parameters
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 1
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PlotYAxisLabelWidget(
                  channels: {"Test": ChannelSetting()},
                  normalizedValue: 1.0))));

      // Then the normalized value is displayed
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "1.00");
    });

    testWidgets(
        "Min is 0 and max is positive, correct normalized value is displayed",
        (WidgetTester tester) async {
      // Given a set of PlotYAxisLabelWidgets with min: 0 and max: 10
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 0, 0.1, 0.5 and 1
      final channels = {"Test": ChannelSetting(min: 0, max: 10)};
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.0),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.1),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.5),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 1.0)
      ]))));

      // Then the displayed values are...
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "0.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "1.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "5.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "10.00");
    });

    testWidgets(
        "Min is negative and max is positive, correct normalized value is displayed",
        (WidgetTester tester) async {
      // Given a set of PlotYAxisLabelWidgets with min: -10 and max: 10
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 0, 0.1, 0.5 and 1
      final channels = {"Test": ChannelSetting(min: -10, max: 10)};
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.0),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.1),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.5),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 0.6),
        PlotYAxisLabelWidget(channels: channels, normalizedValue: 1.0)
      ]))));

      // Then the displayed values are...
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "-10.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "-8.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "0.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "2.00");
      assertPlotYAxisLabel(
          isVisible: true, color: Colors.red, withText: "10.00");
    });
  });
}
