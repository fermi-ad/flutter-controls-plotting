import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/scalar_data_options.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/test_harness/actions.dart';
import 'package:flutter_controls_plotting/test_harness/assertions.dart';
import 'package:flutter_controls_plotting/test_harness/setup.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_y_axis_label_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Stream handling", () {
    testWidgets("Plot API TEST CONSTANT, startPlot is called once", (
      WidgetTester tester,
    ) async {
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

    testWidgets(
      "Plot API TEST CONSTANT and then add API TEST RAMP, startPlot is called twice",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // ... and I have built the PlotWidget one time
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // When I add a channel
        channelList["API TEST RAMP"] = ChannelSetting();

        // ... amd rebuild the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // Then startPlot was called only once
        expect(service.startPlotCount, 2);
      },
    );

    testWidgets(
      "Plot API TEST CONSTANT and then rebuild, startPlot is called only once",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // ... and I have built the PlotWidget one time
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // When I rebuild the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // Then startPlot was called only once
        expect(service.startPlotCount, 1);
      },
    );

    testWidgets(
      "Change updateDelay and then rebuild PlotWidget, startPlot is called again",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // ... and I have built the PlotWidget one time
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // When I change the DAQ settings and rebuild the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service, updateDelay: 50),
        );
        await waitForPlotDataToLoad(tester);

        // Then startPlot was called only once
        expect(service.startPlotCount, 2);
      },
    );

    testWidgets(
      "Build PlotWidget without passing nAcquisitions, startPlot is called with nAcquisitions set to null",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // When I build PlotWidget without specifying nAcquisitions
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // Then nAcquistions = null is passed to the API
        expect(service.startPlotnAcquistions, null);
      },
    );

    testWidgets(
      "Pass nAcquisitions = 1 to PlotWidget, startPlot is called with nAcquisitions = 1",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // When I build PlotWidget with nAcquisitions = 1
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service, nAcquisitions: 1),
        );
        await waitForPlotDataToLoad(tester);

        // Then nAcquistions = 0 is passed to the API
        expect(service.startPlotnAcquistions, 1);
      },
    );

    testWidgets(
      "Change nAcquisitions and then rebuild PlotWidget, startPlot is called again",
      (WidgetTester tester) async {
        // Given a FakeAcsysService
        final service = FakeACSysService();

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // ... and I have built the PlotWidget one time
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service),
        );
        await waitForPlotDataToLoad(tester);

        // When I change the nAcquisitions and rebuild the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, service: service, nAcquisitions: 1),
        );
        await waitForPlotDataToLoad(tester);

        // Then startPlot was called twiced
        expect(service.startPlotCount, 2);
        expect(service.startPlotnAcquistions, 1);
      },
    );

    testWidgets(
      "Supply an onPlotUpdate handler, receive a PlotReply when data is plotted",
      (WidgetTester tester) async {
        // Given a FakeAcsysService and an empty PlotReply
        final service = FakeACSysService();
        PlotReply? lastUpdate;

        // ... and a channel list containing API TEST CONSTANT
        final channelList = {"API TEST CONSTANT": ChannelSetting()};

        // ... and I have built the PlotWidget supplying it with an onPlotUpdate handler
        await tester.pumpWidget(
          _buildPlotWidget(
            channelList,
            service: service,
            onPlotUpdate: (PlotReply update) => lastUpdate = update,
          ),
        );

        // When I wait for data to load
        await waitForPlotDataToLoad(tester);

        // Then a PlotReply was received
        expect(lastUpdate, isNotNull);

        // We get a single scalar device response.
        expect(lastUpdate!.data.first.points.length, 1);

        var deviceValue =
            lastUpdate!.data.first.points.first.value as DevScalarArray;

        // ... and the PlotReply contains 500 samples of data
        expect(deviceValue.value.length, 500);
      },
    );
  });

  group("Error handling", () {
    testWidgets("Dismiss error message, error banner goes away", (
      WidgetTester tester,
    ) async {
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
          "An error occured when attempting to acquire data for PLOT TEST DOESN'T EXIST",
        ),
        findsNothing,
      );
    });

    testWidgets(
      "Dismiss error message, error banner goes away, can appear again",
      (WidgetTester tester) async {
        // Given I tried to plot a channel that had an error
        const errorChannel = "PLOT TEST DOESN'T EXIST";
        const errorMessage =
            "An error occured when attempting to acquire data for $errorChannel";
        Map<String, ChannelSetting> channelList = {
          errorChannel: ChannelSetting(),
        };
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // When I dismiss the error banner
        expect(find.text(errorMessage), findsOneWidget);
        await tester.tap(find.text("Dismiss"));
        await tester.pumpAndSettle();

        // Then the error message is no longer visible
        expect(find.text(errorMessage), findsNothing);

        channelList.clear();
        channelList = {errorChannel: ChannelSetting()};
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        expect(find.text(errorMessage), findsOneWidget);
      },
    );

    testWidgets(
      "Plot a channel with error and channel without, see one channel plotted and an error message",
      (WidgetTester tester) async {
        // Given a channel list with one channel name that doesn't exist
        final channelList = {
          "PLOT TEST CONSTANT": ChannelSetting(),
          "PLOT TEST DOESN'T EXIST": ChannelSetting(),
        };

        // When I try to plot both channels
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then I should the first channel plotted
        assertPlotContainsHorizontalLine(
          tester,
          numberOfPoints: 500,
          atY: 5.0,
          channelName: "PLOT TEST CONSTANT",
        );

        // ... and an error message
        expect(
          find.text(
            "An error occured when attempting to acquire data for PLOT TEST DOESN'T EXIST",
          ),
          findsOneWidget,
        );
      },
    );
  });

  group("PlotWidget (implementation = FlCharts) widget tests", () {
    testWidgets(
      "Verify plot scalar timed data for 10 points. Verify 10 appended points.",
      (WidgetTester tester) async {
        // Given a scalar ramp channel
        var channelName = "PLOT TEST SCALAR RAMP";
        final channelList = {
          channelName: ChannelSetting(lineColor: PlotColor.blue.color),
        };

        // And daq service with scalar ramp point count limit of 10 points.
        StandardPlotDAQ daqService = StandardPlotDAQ();
        daqService.scalarRampCountLimit = 10;

        ConnectionState connectionState = ConnectionState.none;

        // And a update fequency of 10hz with timedScalar option to append to plot.
        await tester.pumpWidget(
          _buildPlotWidget(
            channelList,
            updateDelay: 100000,
            scalarDataOptions: ScalarDataOptions(
              isOneShot: false,
              timeDelta: null,
            ),
            daqService: daqService,
            onStreamConnectionStateChange: (streamConnectionState) =>
                connectionState = streamConnectionState,
          ),
        );

        // Wait for points to load.
        await waitForPlotDataToLoad(tester);
        // Wait until connection is done.
        while (connectionState != ConnectionState.done) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Once done plotting verify that all 10 points were plotted.
        assertPlotContainsNPoints(tester, 10, channelName: channelName);

        // Ensure all timers finish
        await tester.pumpAndSettle();
      },
    );

    testWidgets("Verify support of the panning plot behaviour", (
      WidgetTester tester,
    ) async {
      // Given a mockAdjustXAxisLimits function
      double? lastDeltaX, lastDeltaY;
      void mockAdjustXAxisLimits(double deltaX) {
        lastDeltaX = deltaX;
      }

      void mockAdjustYAxisLimits(double deltaY) {
        lastDeltaY = deltaY;
      }

      // And a channel list containing "PLOT TEST SCALAR RAMP".
      String channelName = "PLOT TEST SCALAR RAMP";
      final channelList = {
        channelName: ChannelSetting(lineColor: PlotColor.blue.color),
      };

      // And daq service with scalar ramp point count limit of 10 points.
      StandardPlotDAQ daqService = StandardPlotDAQ();
      daqService.scalarRampCountLimit = 10;

      // And a update fequency of 10hz with timedScalar option to append to plot.
      await tester.pumpWidget(
        _buildPlotWidget(
          channelList,
          updateDelay: 100000,
          adjustXAxisLimits: mockAdjustXAxisLimits,
          adjustYAxisLimits: mockAdjustYAxisLimits,
          scalarDataOptions: ScalarDataOptions(
            isOneShot: false,
            timeDelta: null,
          ),
          daqService: daqService,
        ),
      );

      // Wait for points to load.
      await waitForPlotDataToLoad(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // Simulate a horizontal drag to the left by 5 logical pixels.
      await tester.drag(find.byType(PlotWidget), const Offset(-5.0, -5.0));
      await tester.pumpAndSettle();

      // Verify that the adjustXAxisLimits function was called with the correct delta.
      expect(lastDeltaX, -5.0);
      expect(lastDeltaY, 5.0);

      // Ensure all timers finish
      await tester.pumpAndSettle(Durations.medium4);
      await tester.pumpAndSettle(Durations.medium4);
    });

    testWidgets(
      "Verify plot scalar on-event 42 points 21 per event. Verify point segments and points.",
      (WidgetTester tester) async {
        // Given a scalar ramp channel
        var channelName = "PLOT TEST SCALAR RAMP";
        final channelList = {
          channelName: ChannelSetting(lineColor: PlotColor.blue.color),
        };

        // And daq service with scalar ramp point count limit of 10 points.
        StandardPlotDAQ daqService = StandardPlotDAQ();
        daqService.scalarRampCountLimit = 42;
        daqService.scalarRampEventDuration = 2;

        ConnectionState connectionState = ConnectionState.none;

        // And a update fequency of 10hz with timedScalar option to append to plot.
        await tester.pumpWidget(
          _buildPlotWidget(
            channelList,
            updateDelay: 100000,
            triggerEvent: 16,
            isPersistent: true,
            scalarDataOptions: ScalarDataOptions(
              isOneShot: false,
              timeDelta: 4,
            ),
            daqService: daqService,
            onStreamConnectionStateChange: (streamConnectionState) =>
                connectionState = streamConnectionState,
          ),
        );

        // Wait for points to load.
        await waitForPlotDataToLoad(tester);
        // Wait until connection is done.
        while (connectionState != ConnectionState.done) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // await tester.pumpAndSettle(const Duration(milliseconds: 1600));

        // Once done plotting verify that all 41 points were plotted.
        assertPlotContainsNPoints(
          tester,
          21,
          channelName: channelName,
          segment: 0,
        );
        assertPlotContainsNPoints(
          tester,
          21,
          channelName: channelName,
          segment: 1,
        );

        assertPlotContainsNSegments(tester, 2, channelName: channelName);

        // Ensure all timers finish
        await tester.pumpAndSettle();
      },
    );

    testWidgets("Plot channel list is empty, plot is empty", (
      WidgetTester tester,
    ) async {
      // Given nothing
      // When I build the PlotWidget with an empty channel list
      await tester.pumpWidget(_buildPlotWidget(const {}));
      await waitForPlotDataToLoad(tester);

      // Then the plot is empty
      assertEmptyPlot(tester, isVisible: true);

      // ... and the Y-axis limits are 0 to 3
      assertPlotYAxisLimits(tester, min: 0, max: 3);

      // ... and the X-axis limits are 0 to 3
      assertPlotXAxisLimits(tester, min: 0, max: 3);
    });

    testWidgets("Plot PLOT TEST CONSTANT, get a horizontal line at y=5.0", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST CONSTANT"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains 500 points with y = 5.0
      assertPlotContainsHorizontalLine(
        tester,
        numberOfPoints: 500,
        atY: 5.0,
        channelName: "PLOT TEST CONSTANT",
      );

      // ... and the Y axis is labeled...
      assertPlotYAxisTitles(
        tester,
        titles: ["PLOT TEST CONSTANT"],
        units: ["V"],
      );

      // ... and the Y-axis has limits of...
      assertPlotYAxisLimits(tester, min: 5, max: 5);
      assertPlotYAxisLabel(
        isVisible: true,
        color: Colors.red,
        withText: "5.00",
      );

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
        assertPlotContainsRamp(
          tester,
          numberOfPoints: 500,
          startingAtY: 0.0,
          channelName: "PLOT TEST RAMP",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(tester, titles: ["PLOT TEST RAMP"], units: ["V"]);

        // ... and the limits for the Y-axis are 0 to 500
        assertPlotYAxisLimits(tester, min: 0, max: 499);
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "0.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "499.00",
        );

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot multiple plots and ensure that the Y and X axis limits are adjusted",
      (WidgetTester tester) async {
        final channelList = {
          "PLOT TEST SINE": ChannelSetting(lineColor: Colors.blue),
        };
        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Ensure that the axis limits accomodate the sine plot test.
        assertPlotXAxisLimits(tester, min: 0, max: 500.0);
        assertPlotYAxisLimits(tester, min: -1, max: 1);
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.blue,
          withText: "-1.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.blue,
          withText: "1.00",
        );

        // Plot a second channel.
        channelList["PLOT TEST CONSTANT"] = ChannelSetting(
          lineColor: Colors.red,
        );
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Ensure that the axis limits changed to accomodate the new plot.
        assertPlotXAxisLimits(tester, min: 0, max: 500);
        assertPlotYAxisLimits(tester, min: 5, max: 5);
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "4.50",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "5.50",
        );
      },
    );

    testWidgets(
      "Plot PLOT TEST PARABOLA, get a parabola starting at X=-50 and ending at X=50",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST PARABOLA": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsParabola(
          tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST PARABOLA",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST PARABOLA"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are -250 to 250
        assertPlotXAxisLimits(tester, min: 0, max: 500.0);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot PLOT TEST SINE, get a sine wave starting at X=-250 and ending at X=250",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST SINE"
        final channelList = {"PLOT TEST SINE": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsSineWave(
          tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST SINE",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(tester, titles: ["PLOT TEST SINE"], units: ["V"]);

        // ... and the limits for the X-axis are 0 to 500
        assertPlotXAxisLimits(tester, min: 0, max: 500.0);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

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
      },
    );

    testWidgets(
      "Plot PLOT TEST PARABOLA 64K, get a parabola starting at X=-32767 and ending at X=32767",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST PARABOLA 64K": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsParabola(
          tester,
          numberOfPoints: 65535,
          startingAtX: -32767,
          channelName: "PLOT TEST PARABOLA 64K",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST PARABOLA 64K"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are -250 to 250
        assertPlotXAxisLimits(tester, min: 0, max: 65534);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot PLOT TEST NORMAL, get a normal distribution centered around 250",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST NORMAL": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a normal distribution around x=250
        assertPlotContainsNormalDistribution(
          tester,
          numberOfPoints: 500,
          centeredAtX: 250,
          channelName: "PLOT TEST NORMAL",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST NORMAL"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are 0 to 499
        assertPlotXAxisLimits(tester, min: 0.0, max: 499.0);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets("Plot API TEST CONST, get a horizontal line at y=5.0", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"API TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with an AcsysProvider
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsHorizontalLine(
        tester,
        numberOfPoints: 500,
        atY: 5.0,
        channelName: "API TEST CONSTANT",
      );

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(
        tester,
        titles: ["API TEST CONSTANT"],
        units: ["A"],
      );

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Small screen, y-axis labels are on top", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // ... and we are rendering for a small display
      await setSmallScreenSize(tester);

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Then the y-axis labels are located on the top of the plot
      assertPlotYAxisTitles(
        tester,
        titles: ["PLOT TEST CONSTANT"],
        units: ["V"],
      );
    });

    testWidgets("Verify plot color applied to newly added channel.", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {
        "PLOT TEST CONSTANT": ChannelSetting(lineColor: PlotColor.blue.color),
      };

      // When I build the PlotWidget
      await tester.pumpWidget(_buildPlotWidget(channelList));
      await waitForPlotDataToLoad(tester);

      // Verify that color is as expected.
      assertColorOfPlot(tester, expectedColor: PlotColor.blue.color);
    });

    testWidgets(
      "Plot two channels with independent y-scales, scales are labeled correctly",
      (WidgetTester tester) async {
        // Given a channel list with two channels and independent y-scales
        final channelList = {
          "PLOT TEST CONSTANT": ChannelSetting(
            lineColor: PlotColor.red.color,
            confMinY: 0.00,
            confMaxY: 10.00,
          ),
          "PLOT TEST RAMP": ChannelSetting(
            lineColor: PlotColor.blue.color,
            confMinY: -5.00,
            confMaxY: 5.00,
          ),
        };

        // When I plot both channels
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then the correct min/max values for the two scales are displayed
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "0.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.blue,
          withText: "-5.00",
        );

        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.red,
          withText: "10.00",
        );
        assertPlotYAxisLabel(
          isVisible: true,
          color: Colors.blue,
          withText: "5.00",
        );
      },
    );

    testWidgets(
      "Plot two channels with independent y-scales, the correct number of labels is displayed",
      (WidgetTester tester) async {
        // Given a small desktop display size
        await setDesktopScreenSize(tester);

        // ... and a channel list with two channels and independent y-scales
        final channelList = {
          "PLOT TEST CONSTANT": ChannelSetting(
            lineColor: PlotColor.red.color,
            confMinY: 0.00,
            confMaxY: 10.00,
          ),
          "PLOT TEST RAMP": ChannelSetting(
            lineColor: PlotColor.blue.color,
            confMinY: -5.00,
            confMaxY: 5.00,
          ),
        };

        // When I plot both channels
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then a total of 11 y-axis labels are displayed
        assertPlotYAxisLabelsCount(tester, 21);
      },
    );

    testWidgets(
      "Plot four channels with independent y-scales, the correct number of labels is displayed",
      (WidgetTester tester) async {
        // Given a small desktop display size
        await setDesktopScreenSize(tester);

        // ... and a channel list with two channels and independent y-scales
        final channelList = {
          "PLOT TEST CONSTANT": ChannelSetting(
            lineColor: PlotColor.red.color,
            confMinY: 0.00,
            confMaxY: 10.00,
          ),
          "PLOT TEST RAMP": ChannelSetting(
            lineColor: PlotColor.blue.color,
            confMinY: -5.00,
            confMaxY: 5.00,
          ),
          "PLOT TEST RAND RAMP": ChannelSetting(
            lineColor: PlotColor.green.color,
            confMinY: 0.00,
            confMaxY: 5.00,
          ),
          "PLOT TEST SINE": ChannelSetting(
            lineColor: PlotColor.yellow.color,
            confMinY: 0.00,
            confMaxY: 5.00,
          ),
        };

        // When I plot both channels
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then a total of 11 y-axis labels are displayed
        assertPlotYAxisLabelsCount(tester, 11);
      },
    );

    testWidgets(
      "Set x-min and x-max to fractional values, all points are normalized properly",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {
          "PLOT TEST PARABOLA": ChannelSetting(lineColor: PlotColor.blue.color),
        };

        // When I build the PlotWidget with xMin = -249.1 and xMax = 249.1
        await tester.pumpWidget(
          _buildPlotWidget(channelList, xMin: -249.1, xMax: 249.1),
        );
        await waitForPlotDataToLoad(tester);

        // Then all of the spots are between 0 and 1
        assertAllFlSpotsAreNormal(tester);
      },
    );

    testWidgets(
      "Set y-min and y-max to a range less than 1, all points are normalized properly",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST CONTANT"
        //   ... and y-min and y-max set to a range of 0.2
        final channelList = {
          "PLOT TEST CONSTANT": ChannelSetting(
            lineColor: PlotColor.blue.color,
            finalMinY: 4.9,
            finalMaxY: 5.1,
          ),
        };

        // When I build the PlotWidget
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Then all of the spots are between 0 and 1
        assertAllFlSpotsAreNormal(tester);
      },
    );
  });

  group("PlotWidget (implementation = Graphic) widget tests", () {
    testWidgets("Plot channel list is empty, plot is empty", (
      WidgetTester tester,
    ) async {
      // Given an empty channel list
      // When I build the PlotWidget with implementation = eCharts
      await tester.pumpWidget(
        _buildPlotWidget(const {}, impl: PlotImplementation.graphic),
      );
      await waitForPlotDataToLoad(tester);

      // Then plot was built using Flutter eCharts
      assertPlotImplementationIs(
        find.byType(PlotWidget),
        PlotImplementation.graphic,
      );

      // ... and the plot is empty
      assertEmptyPlot(tester, isVisible: true);

      // ... and the Y-axis limits are 0 to 1
      assertPlotYAxisLimits(tester, min: 0, max: 3);

      // ... and the X-axis limits are 0 to 1
      // assertPlotXAxisLimits(tester, min: 0, max: 1);
    });

    testWidgets("Plot PLOT TEST CONSTANT, get a horizontal line at y=5.0", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST CONSTANT"
      final channelList = {"PLOT TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with the Graphic implementation
      await tester.pumpWidget(
        _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
      );
      await waitForPlotDataToLoad(tester);

      // Then the plot contains 500 points with y = 5.0
      assertPlotContainsHorizontalLine(
        tester,
        numberOfPoints: 500,
        atY: 5.0,
        channelName: "PLOT TEST CONSTANT",
      );

      // ... and the Y axis is labeled...
      assertPlotYAxisTitles(
        tester,
        titles: ["PLOT TEST CONSTANT"],
        units: ["V"],
      );

      // ... and the Y-axis has limits of...
      assertPlotYAxisLimits(tester, min: 5, max: 5);

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
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a ramp with 500 points starting at Y=0.0
        assertPlotContainsRamp(
          tester,
          numberOfPoints: 500,
          startingAtY: 0.0,
          channelName: "PLOT TEST RAMP",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(tester, titles: ["PLOT TEST RAMP"], units: ["V"]);

        // ... and the limits for the Y-axis are 0 to 500
        assertPlotYAxisLimits(tester, min: 0, max: 499);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot multiple plots and ensure that the Y and X axis limits are adjusted",
      (WidgetTester tester) async {
        final channelList = {"PLOT TEST SINE": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Ensure that the axis limits accomodate the sine plot test.
        assertPlotXAxisLimits(tester, min: 0, max: 500);
        assertPlotYAxisLimits(tester, min: -1, max: 1);

        // Plot a second channel.
        channelList["PLOT TEST CONSTANT"] = ChannelSetting();
        await tester.pumpWidget(_buildPlotWidget(channelList));
        await waitForPlotDataToLoad(tester);

        // Ensure that the axis limits changed to accomodate the new plot.
        assertPlotXAxisLimits(tester, min: 0, max: 500);
        assertPlotYAxisLimits(tester, min: 5, max: 5);
      },
    );

    testWidgets(
      "Plot PLOT TEST PARABOLA, get a parabola starting at X=-50 and ending at X=50",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST PARABOLA": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsParabola(
          tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST PARABOLA",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST PARABOLA"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are 0 to 500
        assertPlotXAxisLimits(tester, min: 0, max: 500);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot PLOT TEST SINE, get a sine wave starting at X=-250 and ending at X=250",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST SINE"
        final channelList = {"PLOT TEST SINE": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsSineWave(
          tester,
          numberOfPoints: 501,
          startingAtX: -250,
          channelName: "PLOT TEST SINE",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(tester, titles: ["PLOT TEST SINE"], units: ["V"]);

        // ... and the limits for the X-axis are 0 to 500
        assertPlotXAxisLimits(tester, min: 0, max: 500);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot PLOT TEST SINE, get a progress indicator while data is fetched",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST SINE"
        final channelList = {"PLOT TEST SINE": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );

        // Then I should see the progress indicator
        assertPlotLoadingIndicator(isVisible: true);
        await waitForPlotDataToLoad(tester);
      },
    );

    testWidgets(
      "Plot PLOT TEST PARABOLA 64K, get a parabola starting at X=-32767 and ending at X=32767",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST PARABOLA 64K": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a parabola with 500 points starting at X=-250
        assertPlotContainsParabola(
          tester,
          numberOfPoints: 65535,
          startingAtX: -32767,
          channelName: "PLOT TEST PARABOLA 64K",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST PARABOLA 64K"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are -250 to 250
        assertPlotXAxisLimits(tester, min: 0, max: 65534);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets(
      "Plot PLOT TEST NORMAL, get a normal distribution centered around 250",
      (WidgetTester tester) async {
        // Given a channel list containing "PLOT TEST PARABOLA"
        final channelList = {"PLOT TEST NORMAL": ChannelSetting()};

        // When I build the PlotWidget
        await tester.pumpWidget(
          _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
        );
        await waitForPlotDataToLoad(tester);

        // Then the plot contains a normal distribution around x=250
        assertPlotContainsNormalDistribution(
          tester,
          numberOfPoints: 500,
          centeredAtX: 250,
          channelName: "PLOT TEST NORMAL",
        );

        // ... and the Y-axis is labeled
        assertPlotYAxisTitles(
          tester,
          titles: ["PLOT TEST NORMAL"],
          units: ["V"],
        );

        // ... and the limits for the X-axis are 0 to 499
        assertPlotXAxisLimits(tester, min: 0.0, max: 499.0);

        // ... and the X-axis is labeled...
        assertPlotXAxisTitle(tester, title: "Index");
      },
    );

    testWidgets("Plot API TEST CONST, get a horizontal line at y=5.0", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {"API TEST CONSTANT": ChannelSetting()};

      // When I build the PlotWidget with an AcsysProvider
      await tester.pumpWidget(
        _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
      );
      await waitForPlotDataToLoad(tester);

      // Then the plot contains a parabola with 500 points starting at X=-250
      assertPlotContainsHorizontalLine(
        tester,
        numberOfPoints: 500,
        atY: 5.0,
        channelName: "API TEST CONSTANT",
      );

      // ... and the Y-axis is labeled
      assertPlotYAxisTitles(
        tester,
        titles: ["API TEST CONSTANT"],
        units: ["A"],
      );

      // ... and the limits for the X-axis are -250 to 250
      assertPlotXAxisLimits(tester, min: 0, max: 499);

      // ... and the X-axis is labeled...
      assertPlotXAxisTitle(tester, title: "Index");
    });

    testWidgets("Verify plot color applied to newly added channel.", (
      WidgetTester tester,
    ) async {
      // Given a channel list containing "PLOT TEST PARABOLA"
      final channelList = {
        "PLOT TEST CONSTANT": ChannelSetting(lineColor: PlotColor.blue.color),
      };

      // When I build the PlotWidget
      await tester.pumpWidget(
        _buildPlotWidget(channelList, impl: PlotImplementation.graphic),
      );
      await waitForPlotDataToLoad(tester);

      // Verify that color is as expected.
      assertColorOfPlot(tester, expectedColor: PlotColor.blue.color);
    });
  });

  group("PlotWidget (implementation = Fermi) widget tests", () {});
}

void assertPlotYAxisLabelsCount(WidgetTester tester, int n) {
  expect(find.byType(PlotYAxisLabelWidget).evaluate().length, n);
}

void assertPlotImplementationIs(
  Finder finder,
  PlotImplementation implementation,
) {
  final widget = finder.evaluate().first.widget as PlotWidget;
  expect(widget.implementation, implementation);
}

Widget _buildPlotWidget(
  Map<String, ChannelSetting> channelList, {
  PlotImplementation impl = PlotImplementation.flCharts,
  int updateDelay = 0,
  int nAcquisitions = 0,
  int? triggerEvent,
  ScalarDataOptions? scalarDataOptions,
  bool isPersistent = false,
  ACSysServiceAPI? service,
  StandardPlotDAQ? daqService,
  Function(double deltaX)? adjustXAxisLimits,
  Function(double deltaY)? adjustYAxisLimits,
  Function(PlotReply reply)? onPlotUpdate,
  Function(ConnectionState streamConnectionState)?
  onStreamConnectionStateChange,
  double? xMin,
  double? xMax,
}) {
  daqService ??= StandardPlotDAQ();
  return MaterialApp(
    home: Scaffold(
      body: ACSysProvider.factory(service: service ?? FakeACSysService())(
        child: PlotWidget(
          plotChannels: channelList,
          confMinX: xMin,
          confMaxX: xMax,
          implementation: impl,
          plotData: PlotData(),
          updateDelay: updateDelay,
          onStreamConnectionStateChange: onStreamConnectionStateChange,
          triggerEvent: triggerEvent,
          nAcquisitions: nAcquisitions,
          onPlotUpdate: onPlotUpdate,
          isPersistent: isPersistent,
          scalarDataOptions: scalarDataOptions,
          adjustXAxisLimits: adjustXAxisLimits,
          adjustYAxisLimits: adjustYAxisLimits,
          daqService: daqService,
        ),
      ),
    ),
  );
}
