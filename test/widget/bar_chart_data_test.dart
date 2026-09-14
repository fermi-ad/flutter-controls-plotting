import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';

void main() {
  group('BarChartReducer', () {
    PlotReply reply({required List<PlotChannelData> data}) => PlotReply(
      plotId: 'test',
      xAxisUnits: '',
      xAxisMin: 0,
      xAxisMax: 1,
      windowSize: 1,
      requestTime: 1,
      data: data,
    );

    PlotChannelData channel(String name, double value, {int status = 0}) =>
        PlotChannelData(
          name: name,
          units: 'A',
          rate: '',
          status: status,
          points: [PlotPoint(t: 1, value: DevScalar(value))],
        );

    test('preserves device order and replaces the latest current value', () {
      final reducer = BarChartReducer(
        deviceNames: ['A', 'B'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.applyReply(reply(data: [channel('B', 2), channel('A', 1)]));
      expect(reducer.data.deviceNames, ['A', 'B']);
      expect(reducer.data.valueFor('A', 'current')!.value, 1);
      expect(reducer.data.valueFor('B', 'current')!.value, 2);

      reducer.applyReply(reply(data: [channel('A', 3)]));
      expect(reducer.data.valueFor('A', 'current')!.value, 3);
      expect(reducer.data.valueFor('B', 'current')!.value, 2);
    });

    test('preserves reference values when current values stream', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.setReference(device: 'A', value: 10);
      reducer.applyReply(reply(data: [channel('A', 12)]));

      expect(reducer.data.valueFor('A', 'current')!.value, 12);
      expect(reducer.data.valueFor('A', 'reference')!.value, 10);
      expect(reducer.data.valuesFor('A').map((value) => value.key), [
        'reference',
        'current',
      ]);
    });

    test('derives higher, lower, and unchanged comparison intervals', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.setReference(device: 'A', value: 50);
      reducer.applyReply(reply(data: [channel('A', 65)]));
      var comparison = reducer.data.comparisonFor('A')!;
      expect(comparison.direction, BarChangeDirection.higher);
      expect(comparison.baseEnd, 50);
      expect(comparison.barEnd, 65);
      expect(comparison.delta, 15);

      reducer.applyReply(reply(data: [channel('A', 35)]));
      comparison = reducer.data.comparisonFor('A')!;
      expect(comparison.direction, BarChangeDirection.lower);
      expect(comparison.baseEnd, 35);
      expect(comparison.barEnd, 50);
      expect(comparison.delta, -15);

      reducer.applyReply(reply(data: [channel('A', 50)]));
      comparison = reducer.data.comparisonFor('A')!;
      expect(comparison.direction, BarChangeDirection.unchanged);
      expect(comparison.barEnd, 50);
    });

    test('records channel errors without creating a zero-valued bar', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.applyReply(reply(data: [channel('A', 2)]));
      reducer.applyReply(reply(data: [channel('A', 0, status: -1)]));

      expect(reducer.data.valueFor('A', 'current')!.value, 2);
      expect(reducer.data.errorsByDevice['A'], isNotNull);
    });
  });
}
