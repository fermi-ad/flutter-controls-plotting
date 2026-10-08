import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';

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

    test('resolves additive segments into contiguous stack intervals', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.setSegment(device: 'A', key: 'first', label: 'First', value: 2);
      reducer.setSegment(device: 'A', key: 'second', label: 'Second', value: 3);

      final resolved = reducer.data.resolvedStackFor('A');
      expect(resolved.map((segment) => segment.start), [0, 2]);
      expect(resolved.map((segment) => segment.end), [2, 5]);
    });

    test('resolves positive and negative additive segments from zero', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.setSegment(device: 'A', key: 'up', label: 'Up', value: 2);
      reducer.setSegment(device: 'A', key: 'down', label: 'Down', value: -3);
      reducer.setSegment(
        device: 'A',
        key: 'upMore',
        label: 'Up more',
        value: 4,
      );
      reducer.setSegment(
        device: 'A',
        key: 'downMore',
        label: 'Down more',
        value: -5,
      );

      final resolved = reducer.data.resolvedStackFor('A');
      expect(resolved.map((segment) => segment.start), [0, 0, 2, -3]);
      expect(resolved.map((segment) => segment.end), [2, -3, 6, -8]);
    });

    test('accepts contiguous explicit negative ranges', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.setSegment(device: 'A', key: 'first', label: 'First', value: -2);
      reducer.setRangeSegment(
        device: 'A',
        key: 'second',
        label: 'Second',
        start: -2,
        end: -5,
      );

      final resolved = reducer.data.resolvedStackFor('A');
      expect(resolved.map((segment) => segment.start), [0, -2]);
      expect(resolved.map((segment) => segment.end), [-2, -5]);
    });

    test('rejects stacked ranges that cross zero or reverse toward zero', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      expect(
        () => reducer.setRangeSegment(
          device: 'A',
          key: 'crosses',
          label: 'Crosses',
          start: -1,
          end: 1,
        ),
        throwsArgumentError,
      );
      reducer.setSegment(device: 'A', key: 'first', label: 'First', value: -2);
      expect(
        () => reducer.setRangeSegment(
          device: 'A',
          key: 'towardZero',
          label: 'Toward zero',
          start: -2,
          end: -1,
        ),
        throwsArgumentError,
      );
    });

    test('accepts an explicit range contiguous with an additive segment', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.setSegment(device: 'A', key: 'first', label: 'First', value: 2);
      reducer.setRangeSegment(
        device: 'A',
        key: 'second',
        label: 'Second',
        start: 2,
        end: 7,
      );

      final resolved = reducer.data.resolvedStackFor('A');
      expect(resolved.map((segment) => segment.start), [0, 2]);
      expect(resolved.map((segment) => segment.end), [2, 7]);
    });

    test('rejects a gapped or overlapping stacked range without mutation', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.setSegment(device: 'A', key: 'first', label: 'First', value: 2);

      expect(
        () => reducer.setRangeSegment(
          device: 'A',
          key: 'gap',
          label: 'Gap',
          start: 3,
          end: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => reducer.setRangeSegment(
          device: 'A',
          key: 'overlap',
          label: 'Overlap',
          start: 1,
          end: 4,
        ),
        throwsArgumentError,
      );
      expect(reducer.data.segmentsFor('A').map((segment) => segment.key), [
        'first',
      ]);
    });

    test('rejects reversed and non-finite stacked ranges without mutation', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      expect(
        () => reducer.setRangeSegment(
          device: 'A',
          key: 'reversed',
          label: 'Reversed',
          start: 2,
          end: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => reducer.setSegment(
          device: 'A',
          key: 'notFinite',
          label: 'Not finite',
          value: double.nan,
        ),
        throwsArgumentError,
      );
      expect(reducer.data.segmentsFor('A'), isEmpty);
    });
  });
}
