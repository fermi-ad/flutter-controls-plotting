import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/test_harness/actions.dart';
import 'package:flutter_controls_plotting/test_harness/assertions.dart';
import 'package:flutter_controls_plotting/test_harness/setup.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Stream handling", () {
    testWidgets("Plot API TEST CONSTANT, startPlot is called once",
        (WidgetTester tester) async {
      // Given a FakeAcsysService
      final service = FakeACSysService();

      // ... and a channel list containing API TEST CONSTANT
      final channelList = {"API TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList, service: service));
      await waitForPlotDataToLoad(tester);

      // Then startPlot was called only once
      expect(service.startPlotCount, 1);
    });
  });

  group("Error handling", () {
    testWidgets("Dismiss error message, error banner goes away",
        (WidgetTester tester) async {
      // Given I tried to plot a channel that had an error
      final channelList = {"PLOT TEST DOESN'T EXIST": ChannelSetting()};
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // When I dismiss the error banner
      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      // Then the error message is no longer visible
      expect(
          find.text(
              "An error occured when attempting to acquire data for PLOT TEST DOESN'T EXIST"),
          findsNothing);
    });

    testWidgets(
        "Dismiss error message, error banner goes away, can appear again",
        (WidgetTester tester) async {
      // Given I tried to plot a channel that had an error
      const errorChannel = "PLOT TEST DOESN'T EXIST";
      const errorMessage =
          "An error occured when attempting to acquire data for $errorChannel";
      Map<String, ChannelSetting> channelList = {
        errorChannel: ChannelSetting()
      };
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // When I dismiss the error banner
      expect(find.text(errorMessage), findsOne);
      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      // Then the error message is no longer visible
      expect(find.text(errorMessage), findsNothing);

      channelList.clear();
      channelList = {errorChannel: ChannelSetting()};
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      expect(find.text(errorMessage), findsOne);
    });

    testWidgets(
        "Plot a channel with error and channel without, see one channel plotted and an error message",
        (WidgetTester tester) async {
      // Given a channel list with one channel name that doesn't exist
      final channelList = {
        "PLOT TEST CONSTANT": ChannelSetting(),
        "PLOT TEST DOESN'T EXIST": ChannelSetting()
      };

      // When I try to plot both channels
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then I should the first channel plotted
      assertPlotContainsHorizontalLine(tester,
          numberOfPoints: 500, atY: 5.0, channelName: "PLOT TEST CONSTANT");

      // ... and an error message
      expect(
          find.text(
              "An error occured when attempting to acquire data for PLOT TEST DOESN'T EXIST"),
          findsOneWidget);
    });
  });
  group("PlotWidget (implementation = FlCharts) widget tests", () {
    testWidgets("Plot channel list is empty, plot is empty",
        (WidgetTester tester) async {
      // Given nothing
      // When I build the PlotWidget with an empty channel list
      await tester.pumpWidget(_buildPlotWidget(const {}));
      await waitForPlotDataToLoad(tester);

      // Then the plot is empty
      assertEmptyPlot(tester, isVisible: true);

      // ... and the Y-axis limits are 0 to 1
      assertPlotYAxisLimits(tester, min: 0, max: 1);

      // ... and the X-axis limits are 0 to 1
      assertPlotXAxisLimits(tester, min: 0, max: 1);
    });

    testWidgets("Plot PLOT TEST CONSTANT, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST CONSTANT"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains 500 points with y = 5.0
      assertPlotContainsHorizontalLine(tester,
          numberOfPoints: 500, atY: 5.0, channelName: "PLOT TEST CONSTANT");

      // ... and the Y axis is labeled...
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST CONSTANT"], units: ["V"]);

      // ... and the Y-axis has limits of...
      assertPlotYAxisLimits(tester, min: 0, max: 5);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST RAMP, get a ramp starting at Y=0.0 and ending at y = 500.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST RAMP"
      final channelList = {"PLOT TEST RAMP": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a ramp with 500 points starting at Y=0.0
      assertPlotContainsRamp(tester,
          numberOfPoints: 500, startingAtY: 0.0, channelName: "PLOT TEST RAMP");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST RAMP"], units: ["V"]);

      // ... and the limits for the Y-axis are 0 to 500
      assertPlotYAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot multiple plots and ensure that the Y and X axis limits are adjusted",
        (WidgetTester tester) async {
      final channelList = {"PLOT TEST SINE": ChannelSetting()};
      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Ensure that the axis limits accomodate the sine plot test.
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);
      assertPlotYAxisLimits(tester, min: -1, max: 1);

      // Plot a second channel.
      channelList["PLOT TEST CONSTANT"] = ChannelSetting();
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Ensure that the axis limits changed to accomodate the new plot.
      assertPlotXAxisLimits(tester, min: -250, max: 499);
      assertPlotYAxisLimits(tester, min: -1, max: 5);
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA, get a parabola starting at X=-50 and ending at X=50",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST PARABOLA": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST PARABOLA");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST PARABOLA"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a sine wave starting at X=-250 and ending at X=250",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = {"PLOT TEST SINE": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsSineWave(tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST SINE");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST SINE"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a progress indicator while data is fetched",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = {"PLOT TEST SINE": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));

      // Then I should see the progress indicator
      assertPlotLoadingIndicator(isVisible: true);
      await waitForPlotDataToLoad(tester);
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA 64K, get a parabola starting at X=-32767 and ending at X=32767",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST PARABOLA 64K": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(tester,
          numberOfPoints: 65535,
          startingAtX: -32767,
          channelName: "PLOT TEST PARABOLA 64K");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST PARABOLA 64K"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -32767.0, max: 32767.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST NORMAL, get a normal distribution centered around 250",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST NORMAL": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a normal distribution around x=250
      assertPlotContainsNormalDistribution(tester,
          numberOfPoints: 500,
          centeredAtX: 250,
          channelName: "PLOT TEST NORMAL");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST NORMAL"], units: ["V"]);

      // ... and the limits for the X-axis are 0 to 499
      assertPlotXAxisLimits(tester, min: 0.0, max: 499.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Plot API TEST CONST, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"API TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with an AcsysProvider
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsHorizontalLine(tester,
          numberOfPoints: 500, atY: 5.0, channelName: "API TEST CONSTANT");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["API TEST CONSTANT"], units: ["A"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Small screen, y-axis labels are on top",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // ... and we are rendering for a small display
      await setSmallScreenSize(tester);

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the y-axis labels are located on the top of the plot
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST CONSTANT"], units: ["V"]);
    });

    testWidgets("Verify plot color applied to newly added channel.",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {
        "PLOT TEST CONSTANT": ChannelSetting(lineColor: PlotColor.blue.color)
      };

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Verify that color is as expected.
      assertColorOfPlot(tester, expectedColor: PlotColor.blue.color);
    });
  });

  group("PlotWidget (implementation = Graphic) widget tests", () {
    testWidgets("Plot channel list is empty, plot is empty",
        (WidgetTester tester) async {
      // Given an empty channel list
      // When I build the PlotWidget with implementation = eCharts
      await tester.pumpWidget(
          _buildPlotWidget(const {}, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then plot was built using Flutter eCharts
      assertPlotImplementationIs(
          find.byType(PlotWidget), PlotImplementation.graphic);

      // ... and the plot is empty
      assertEmptyPlot(tester, isVisible: true);

      // ... and the Y-axis limits are 0 to 1
      assertPlotYAxisLimits(tester, min: 0, max: 1);

      // ... and the X-axis limits are 0 to 1
      // assertPlotXAxisLimits(tester, min: 0, max: 1);
    });

    testWidgets("Plot PLOT TEST CONSTANT, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST CONSTANT"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with the Graphic implementation
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains 500 points with y = 5.0
      assertPlotContainsHorizontalLine(tester,
          numberOfPoints: 500, atY: 5.0, channelName: "PLOT TEST CONSTANT");

      // ... and the Y axis is labeled...
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST CONSTANT"], units: ["V"]);

      // ... and the Y-axis has limits of...
      assertPlotYAxisLimits(tester, min: 0, max: 5);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST RAMP, get a ramp starting at Y=0.0 and ending at y = 500.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST RAMP"
      final channelList = {"PLOT TEST RAMP": ChannelSetting()};

      // When I build the PlotWidget with implementation = Graphic
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a ramp with 500 points starting at Y=0.0
      assertPlotContainsRamp(tester,
          numberOfPoints: 500, startingAtY: 0.0, channelName: "PLOT TEST RAMP");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST RAMP"], units: ["V"]);

      // ... and the limits for the Y-axis are 0 to 500
      assertPlotYAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot multiple plots and ensure that the Y and X axis limits are adjusted",
        (WidgetTester tester) async {
      final channelList = {"PLOT TEST SINE": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Ensure that the axis limits accomodate the sine plot test.
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);
      assertPlotYAxisLimits(tester, min: -1, max: 1);

      // Plot a second channel.
      channelList["PLOT TEST CONSTANT"] = ChannelSetting();
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Ensure that the axis limits changed to accomodate the new plot.
      assertPlotXAxisLimits(tester, min: -250, max: 499);
      assertPlotYAxisLimits(tester, min: -1, max: 5);
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA, get a parabola starting at X=-50 and ending at X=50",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST PARABOLA": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST PARABOLA");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST PARABOLA"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a sine wave starting at X=-250 and ending at X=250",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = {"PLOT TEST SINE": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsSineWave(tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST SINE");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST SINE"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -250.0, max: 250.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST SINE, get a progress indicator while data is fetched",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST SINE"
      final channelList = {"PLOT TEST SINE": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));

      // Then I should see the progress indicator
      assertPlotLoadingIndicator(isVisible: true);
      await waitForPlotDataToLoad(tester);
    });

    testWidgets(
        "Plot PLOT TEST PARABOLA 64K, get a parabola starting at X=-32767 and ending at X=32767",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST PARABOLA 64K": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsParabola(tester,
          numberOfPoints: 65535,
          startingAtX: -32767,
          channelName: "PLOT TEST PARABOLA 64K");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["PLOT TEST PARABOLA 64K"], units: ["V"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: -32767.0, max: 32767.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets(
        "Plot PLOT TEST NORMAL, get a normal distribution centered around 250",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST NORMAL": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a normal distribution around x=250
      assertPlotContainsNormalDistribution(tester,
          numberOfPoints: 500,
          centeredAtX: 250,
          channelName: "PLOT TEST NORMAL");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester, titles: ["PLOT TEST NORMAL"], units: ["V"]);

      // ... and the limits for the X-axis are 0 to 499
      assertPlotXAxisLimits(tester, min: 0.0, max: 499.0);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Plot API TEST CONST, get a horizontal line at y=5.0",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"API TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with an AcsysProvider
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsHorizontalLine(tester,
          numberOfPoints: 500, atY: 5.0, channelName: "API TEST CONSTANT");

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(tester,
          titles: ["API TEST CONSTANT"], units: ["A"]);

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Verify plot color applied to newly added channel.",
        (WidgetTester tester) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {
        "PLOT TEST CONSTANT": ChannelSetting(lineColor: PlotColor.blue.color)
      };

      // When I build the PlotWidget
      await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic));
      await waitForPlotDataToLoad(tester);

      // Verify that color is as expected.
      assertColorOfPlot(tester, expectedColor: PlotColor.blue.color);
    });
  });

  group("PlotWidget (implementation = Fermi) widget tests", () {});
}

void assertPlotImplementationIs(
    Finder finder, PlotImplementation implementation) {
  final widget = finder.evaluate().first.widget as PlotWidget;
  expect(widget.implementation, implementation);
}

Widget _buildPlotWidget(Map<String, ChannelSetting> channelList,
        {PlotImplementation impl = PlotImplementation.flCharts,
        ACSysServiceAPI? service}) =>
    MaterialApp(
        home: Scaffold(
            body: ACSysProvider(
                service: service ?? FakeACSysService(),
                child: PlotWidget(
                    plotChannels: channelList,
                    implementation: impl,
                    daqService: const StandardPlotDAQ()))));
