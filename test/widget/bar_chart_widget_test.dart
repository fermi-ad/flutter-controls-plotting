import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_controller.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/bar_chart_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarChartWidget', () {
    testWidgets('shows placeholder text when devices is empty', (tester) async {
      await tester.pumpWidget(
        _harness(
          BarChartWidget(devices: const [], daqService: StandardPlotDAQ()),
        ),
      );

      expect(find.text('No devices selected'), findsOneWidget);
    });

    testWidgets(
      'external controller mutations rebuild the chart and invoke onDataChanged',
      (tester) async {
        final controller = BarChartController(
          deviceNames: ['Device A'],
          colorForDevice: (_) => Colors.blue,
        );
        var callbackCount = 0;

        await tester.pumpWidget(
          _harness(
            BarChartWidget(
              devices: const ['Device A'],
              daqService: StandardPlotDAQ(),
              controller: controller,
              onDataChanged: (_) => callbackCount++,
            ),
          ),
        );
        await tester.pump();

        // No segments yet: fl_chart renders a group with zero rods.
        var chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups.single.barRods, isEmpty);

        // Mutating the controller directly (as an external owner would)
        // must be reflected in the rendered chart without any manual
        // setState call from the caller.
        controller.setSegment(
          device: 'Device A',
          key: 'setpoint',
          label: 'Setpoint',
          value: 42,
        );
        await tester.pump();

        chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups.single.barRods, hasLength(1));
        expect(chart.data.barGroups.single.barRods.single.toY, 42);
        expect(callbackCount, greaterThan(0));

        controller.dispose();
      },
    );

    testWidgets('does not dispose an externally-supplied controller', (
      tester,
    ) async {
      final controller = BarChartController(deviceNames: const ['A']);

      await tester.pumpWidget(
        _harness(
          BarChartWidget(
            devices: const ['A'],
            daqService: StandardPlotDAQ(),
            controller: controller,
          ),
        ),
      );
      await tester.pump();

      // Remove the widget from the tree.
      await tester.pumpWidget(const SizedBox());

      // The externally-owned controller must still be usable after the
      // widget has been disposed.
      expect(
        () => controller.setSegment(
          device: 'A',
          key: 'value',
          label: 'Value',
          value: 1,
        ),
        returnsNormally,
      );

      controller.dispose();
    });
  });
}

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(
    body: ACSysProvider.factory(service: FakeACSysService())(child: child),
  ),
);
