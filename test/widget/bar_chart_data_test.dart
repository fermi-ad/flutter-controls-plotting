import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_controller.dart';
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

    PlotChannelData channel(
      String name,
      double value, {
      int status = 0,
      String units = 'A',
      double timestamp = 1,
    }) => PlotChannelData(
      name: name,
      units: units,
      rate: '',
      status: status,
      points: [PlotPoint(t: timestamp, value: DevScalar(value))],
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

    for (final sign in [1.0, -1.0]) {
      final side = sign > 0 ? 'positive' : 'negative';

      test('rejects removal before a $side range atomically', () {
        final reducer = BarChartReducer(
          deviceNames: ['B', 'A'],
          style: const BarChartStyle(layout: BarChartLayout.stacked),
        );
        reducer.applyReply(
          reply(data: [channel('B', 4), channel('A', sign * 2)]),
        );
        reducer.setRangeSegment(
          device: 'A',
          key: 'range',
          label: 'Range',
          start: sign * 2,
          end: sign * 7,
        );
        reducer.applyReply(reply(data: [channel('B', 0, status: -1)]));
        final before = reducer.data;

        expect(
          () => reducer.clearSegment(device: 'A', key: 'value'),
          throwsArgumentError,
        );
        expect(reducer.data, same(before));
        // B is processed first, but its otherwise valid removal must roll back.
        expect(() => reducer.clearSegment(key: 'value'), throwsArgumentError);
        expect(reducer.data, same(before));
        expect(reducer.data.segmentFor('B', 'value')!.value, 4);
        expect(reducer.data.unitsByDevice, {'B': 'A', 'A': 'A'});
        expect(reducer.data.errorsByDevice['B'], isNotNull);
        final resolved = reducer.data.resolvedStackFor('A');
        expect(resolved.map((segment) => segment.start), [0, sign * 2]);
        expect(resolved.map((segment) => segment.end), [sign * 2, sign * 7]);

        reducer.clearSegment(device: 'A', key: 'range');
        reducer.clearSegment(device: 'A', key: 'value');
        expect(reducer.data.resolvedStackFor('A'), isEmpty);
        expect(before.segmentsFor('A'), hasLength(2));
      });

      test('rejects streamed changes before a $side range atomically', () {
        final reducer = BarChartReducer(
          deviceNames: ['A', 'B', 'C'],
          style: const BarChartStyle(layout: BarChartLayout.stacked),
        );
        reducer.applyReply(
          reply(data: [channel('A', sign * 2), channel('B', 4)]),
        );
        reducer.setRangeSegment(
          device: 'A',
          key: 'range',
          label: 'Range',
          start: sign * 2,
          end: sign * 7,
        );
        reducer.applyReply(reply(data: [channel('B', 0, status: -1)]));
        final before = reducer.data;

        // Cover gaps, overlaps, zero, and changes to the opposite signed side.
        for (final value in [sign, sign * 3, 0.0, -sign * 2]) {
          expect(
            () => reducer.applyReply(
              reply(
                data: [
                  channel('B', 9, units: 'V', timestamp: 2),
                  channel('C', 0, status: -2),
                  channel('A', value, units: 'V', timestamp: 2),
                ],
              ),
            ),
            throwsArgumentError,
          );
          expect(reducer.data, same(before));
          expect(reducer.data.segmentFor('B', 'value')!.value, 4);
          expect(reducer.data.segmentFor('A', 'value')!.timestamp, 1);
          expect(reducer.data.unitsByDevice, {'A': 'A', 'B': 'A'});
          expect(reducer.data.errorsByDevice, {'B': 'Channel error (-1)'});
          final resolved = reducer.data.resolvedStackFor('A');
          expect(resolved.map((segment) => segment.start), [0, sign * 2]);
          expect(resolved.map((segment) => segment.end), [sign * 2, sign * 7]);
        }

        // An unchanged reading still accepts new metadata without rebasing.
        reducer.applyReply(
          reply(data: [channel('A', sign * 2, units: 'V', timestamp: 3)]),
        );
        expect(
          reducer.data.segmentFor('A', 'range'),
          same(before.segmentFor('A', 'range')),
        );
        expect(reducer.data.segmentFor('A', 'value')!.timestamp, 3);
        expect(reducer.data.unitsByDevice['A'], 'V');
        expect(reducer.data.errorsByDevice, isEmpty);
      });

      test('can clear a complete $side stack while retaining metadata', () {
        final reducer = BarChartReducer(
          deviceNames: ['A', 'B'],
          style: const BarChartStyle(layout: BarChartLayout.stacked),
        );
        reducer.applyReply(
          reply(data: [channel('A', sign * 2), channel('B', sign * 2)]),
        );
        for (final device in ['A', 'B']) {
          reducer.setRangeSegment(
            device: device,
            key: 'range',
            label: 'Range',
            start: sign * 2,
            end: sign * 7,
          );
        }
        reducer.applyReply(reply(data: [channel('A', 0, status: -1)]));
        final before = reducer.data;

        reducer.clearSegment(device: 'A');
        expect(reducer.data.resolvedStackFor('A'), isEmpty);
        expect(reducer.data.resolvedStackFor('B'), hasLength(2));
        reducer.clearSegment();
        expect(reducer.data.segmentsByDevice, isEmpty);
        expect(reducer.data.deviceNames, ['A', 'B']);
        expect(reducer.data.unitsByDevice, before.unitsByDevice);
        expect(reducer.data.errorsByDevice, before.errorsByDevice);
      });
    }

    test('opposite-side changes do not invalidate an explicit range', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.applyReply(reply(data: [channel('A', -2)]));
      reducer.setRangeSegment(
        device: 'A',
        key: 'range',
        label: 'Range',
        start: 0,
        end: 5,
      );
      reducer.applyReply(reply(data: [channel('A', -3)]));
      reducer.clearSegment(device: 'A', key: 'value');
      final resolved = reducer.data.resolvedStackFor('A');
      expect(resolved.single.start, 0);
      expect(resolved.single.end, 5);
    });

    test('additive segments follow streamed changes and removals', () {
      final reducer = BarChartReducer(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      reducer.applyReply(reply(data: [channel('A', 2)]));
      reducer.setSegment(device: 'A', key: 'extra', label: 'Extra', value: 5);
      reducer.applyReply(reply(data: [channel('A', 3)]));
      final updated = reducer.data.resolvedStackFor('A');
      expect(updated.map((segment) => segment.start), [0, 3]);
      expect(updated.map((segment) => segment.end), [3, 8]);
      reducer.clearSegment(device: 'A', key: 'value');
      final remaining = reducer.data.resolvedStackFor('A');
      expect(remaining.single.start, 0);
      expect(remaining.single.end, 5);
    });

    test('controller does not notify listeners for rejected stack edits', () {
      final controller = BarChartController(
        deviceNames: ['A'],
        style: const BarChartStyle(layout: BarChartLayout.stacked),
      );
      addTearDown(controller.dispose);
      controller.applyReply(reply(data: [channel('A', 2)]));
      controller.setRangeSegment(
        device: 'A',
        key: 'range',
        label: 'Range',
        start: 2,
        end: 7,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final before = controller.data;

      expect(
        () => controller.clearSegment(device: 'A', key: 'value'),
        throwsArgumentError,
      );
      expect(
        () => controller.applyReply(reply(data: [channel('A', 3)])),
        throwsArgumentError,
      );
      expect(controller.data, same(before));
      expect(notifications, 0);
      controller.clearSegment(device: 'A');
      expect(controller.data.resolvedStackFor('A'), isEmpty);
      expect(notifications, 1);
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
