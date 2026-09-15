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

    test('preserves device order and replaces the latest value segment', () {
      final reducer = BarChartReducer(
        deviceNames: ['A', 'B'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.applyReply(reply(data: [channel('B', 2), channel('A', 1)]));
      expect(reducer.data.deviceNames, ['A', 'B']);
      expect(reducer.data.segmentFor('A', 'value')!.value, 1);
      expect(reducer.data.segmentFor('B', 'value')!.value, 2);

      reducer.applyReply(reply(data: [channel('A', 3)]));
      expect(reducer.data.segmentFor('A', 'value')!.value, 3);
      expect(reducer.data.segmentFor('B', 'value')!.value, 2);
    });

    test('preserves manually-set segments when streamed values update', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.setSegment(
        device: 'A',
        key: 'setpoint',
        label: 'Setpoint',
        value: 10,
      );
      reducer.applyReply(reply(data: [channel('A', 12)]));

      expect(reducer.data.segmentFor('A', 'value')!.value, 12);
      expect(reducer.data.segmentFor('A', 'setpoint')!.value, 10);
      expect(reducer.data.segmentsFor('A').map((s) => s.key), [
        'setpoint',
        'value',
      ]);
    });

    test('supports multiple independent segments per device', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.setSegment(
        device: 'A',
        key: 'setpoint',
        label: 'Setpoint',
        value: 50,
        color: Colors.grey,
      );
      reducer.setSegment(
        device: 'A',
        key: 'limit',
        label: 'Limit',
        value: 90,
        color: Colors.red,
      );
      reducer.applyReply(reply(data: [channel('A', 65)]));

      final segments = reducer.data.segmentsFor('A');
      expect(segments, hasLength(3));
      expect(segments.map((s) => s.key), ['setpoint', 'limit', 'value']);
      expect(reducer.data.segmentFor('A', 'limit')!.value, 90);
      expect(reducer.data.segmentFor('A', 'limit')!.color, Colors.red);
    });

    test('clearSegment removes a single segment or all segments', () {
      final reducer = BarChartReducer(
        deviceNames: ['A', 'B'],
        colorForDevice: (_) => Colors.blue,
      );
      reducer.setSegment(device: 'A', key: 'setpoint', label: 'S', value: 1);
      reducer.setSegment(device: 'A', key: 'limit', label: 'L', value: 2);
      reducer.setSegment(device: 'B', key: 'setpoint', label: 'S', value: 3);

      reducer.clearSegment(device: 'A', key: 'setpoint');
      expect(reducer.data.segmentFor('A', 'setpoint'), isNull);
      expect(reducer.data.segmentFor('A', 'limit'), isNotNull);
      expect(reducer.data.segmentFor('B', 'setpoint'), isNotNull);

      reducer.clearSegment();
      expect(reducer.data.segmentsFor('A'), isEmpty);
      expect(reducer.data.segmentsFor('B'), isEmpty);
    });

    test('records channel errors without creating a zero-valued bar', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        colorForDevice: (_) => Colors.blue,
      );

      reducer.applyReply(reply(data: [channel('A', 2)]));
      reducer.applyReply(reply(data: [channel('A', 0, status: -1)]));

      expect(reducer.data.segmentFor('A', 'value')!.value, 2);
      expect(reducer.data.errorsByDevice['A'], isNotNull);
    });

    test('falls back to style.defaultColor when colorForDevice is omitted', () {
      final reducer = BarChartReducer(deviceNames: ['A']);
      reducer.applyReply(reply(data: [channel('A', 5)]));
      expect(
        reducer.data.segmentFor('A', 'value')!.color,
        reducer.style.defaultColor,
      );
    });
  });
}
