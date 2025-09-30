import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/test_harness/assertions.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotYAxisLabelWidget widget tests", () {
    testWidgets("No min/max given, normalized value is displayed", (
      WidgetTester tester,
    ) async {
      // Given a PlotYAxisLabelWidget with no min: or max: parameters
      // When I build the PlotYAxisLabelWidget with a normalizedValue of 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotYAxisLabelWidget(
              channels: {"Test": ChannelSetting(lineColor: Colors.red)},
              normalizedValue: 1.0,
            ),
          ),
        ),
      );

      // Then the normalized value is displayed
      assertPlotYAxisLabel(
        isVisible: true,
        color: Colors.red,
        withText: "1.00",
      );
    });

    testWidgets(
      "Min is 0 and max is positive, correct normalized value is displayed",
      (WidgetTester tester) async {
        // Given a set of PlotYAxisLabelWidgets with min: 0 and max: 10
        // When I build the PlotYAxisLabelWidget with a normalizedValue of 0, 0.1, 0.5 and 1
        final channels = {
          "Test": ChannelSetting(
            finalMinY: 0,
            finalMaxY: 10,
            lineColor: Colors.red,
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.0,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.1,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.5,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 1.0,
                  ),
                ],
              ),
            ),
          ),
        );

        // Then the displayed values are...
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "0.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "1.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "5.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "10.00",
        );
      },
    );

    testWidgets(
      "Min is negative and max is positive, correct normalized value is displayed",
      (WidgetTester tester) async {
        // Given a set of PlotYAxisLabelWidgets with min: -10 and max: 10
        // When I build the PlotYAxisLabelWidget with a normalizedValue of 0, 0.1, 0.5 and 1
        final channels = {
          "Test": ChannelSetting(
            finalMinY: -10,
            finalMaxY: 10,
            lineColor: Colors.red,
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.0,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.1,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.5,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.6,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 1.0,
                  ),
                ],
              ),
            ),
          ),
        );

        // Then the displayed values are...
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "-10.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "-8.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "0.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "2.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "10.00",
        );
      },
    );

    testWidgets(
      "Set defaultMin and defaultMax, used when channel-level min and max are not set",
      (WidgetTester tester) async {
        // Given a list of channels with varying y-scales
        final channels = {
          "Test1": ChannelSetting(
            lineColor: Colors.red,
            finalMinY: -10,
            finalMaxY: 10,
          ),
          "Test3": ChannelSetting(lineColor: Colors.green),
        };

        // When I build the PlotYAxisLabelWidgets for normalized values of 0 and 1 and global min/max of 0 to 10
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 0.0,
                    defaultMin: 0,
                    defaultMax: 5,
                  ),
                  PlotYAxisLabelWidget(
                    channels: channels,
                    normalizedValue: 1.0,
                    defaultMin: 0,
                    defaultMax: 5,
                  ),
                ],
              ),
            ),
          ),
        );

        // Then the global min and max is used for every channel
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "-10.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.green,
          withText: "0.00",
        );

        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "10.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.green,
          withText: "5.00",
        );
      },
    );
  });
}
