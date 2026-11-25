import 'dart:async';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_controls_plotting/entities/channel_metadata.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/flchart_cache.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/plotting_fl_spot.dart';
import 'package:flutter_controls_plotting/entities/scalar_data_options.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

const channelName = 'synthetic';

PlotChannelData packet(int index, {int size = 8192, int status = 0}) =>
    PlotChannelData(
      name: channelName,
      units: '',
      rate: '',
      status: status,
      points: status == 0
          ? [
              PlotPoint(
                t: index.toDouble(),
                value: DevScalarArray(Float64List(size)),
              ),
            ]
          : [],
    );

PlotReply reply(int index, {required int size}) => PlotReply(
  plotId: 'diagnostic',
  requestTime: index.toDouble(),
  xAxisUnits: 'Index',
  data: [packet(index, size: size)],
);

void main() {
  test('bounded chart cache preserves order at both viewport edges', () {
    final data = PlotData();
    data.filterPoints(
      isTimedScalarData: false,
      isPersistent: false,
      isOneShot: false,
      plotChannels: [packet(1, size: 10)],
      triggerTimestamp: null,
    );
    final spots = data.flchartCache.toSpots(
      points: data.points[channelName]!.single,
      channelName: channelName,
      segmentIndex: 0,
      channelSetting: ChannelSetting(),
      minX: 2,
      maxX: 7,
      spotBudget: 4,
    );
    expect(spots.map((spot) => spot.x), orderedEquals([1.0, 2.0, 7.0, 8.0]));
  });
  test(
    'a failed first scalar reply leaves the plot waiting for usable bounds',
    () {
      final data = PlotData();
      void calculate(PlotChannelData channel) => data.findLimits(
        plotChannels: [channel],
        confMinX: null,
        confMaxX: null,
        timeDelta: 5,
        triggerTimestamp: null,
        isPersistent: false,
        isTriggered: false,
      );
      calculate(packet(1, status: -1));
      expect(data.plotMetadata.xMax, isNull);
      calculate(
        PlotChannelData(
          name: channelName,
          units: '',
          rate: '',
          status: 0,
          points: [PlotPoint(t: 100.0, value: DevScalar(7))],
        ),
      );
      expect(data.plotMetadata.xMin, 95);
      expect(data.plotMetadata.xMax, 100);
    },
  );

  testWidgets('device X plots keep rendered points when X wraps', (
    tester,
  ) async {
    final service = BurstService();
    final data = PlotData();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlotWidget(
            daqService: service,
            plotData: data,
            plotChannels: {
              channelName: ChannelMetadata(
                channelSetting: ChannelSetting(confMinY: 0, confMaxY: 100),
              ),
            },
            scalarDataOptions: ScalarDataOptions(
              isOneShot: false,
              timeDelta: null,
            ),
            chXAxis: 'G:SCTIME',
            confMinX: 0,
            confMaxX: 65,
          ),
        ),
      ),
    );

    final stream = service.streams.single;
    Future<void> send(List<double> xValues) async {
      stream.add(
        PlotReply(
          plotId: 'device-x',
          requestTime: 1000,
          xAxisUnits: 'G:SCTIME',
          data: [
            PlotChannelData(
              name: channelName,
              units: '',
              rate: '',
              status: 0,
              points: [
                for (final x in xValues)
                  PlotPoint(t: x, value: DevScalar(x + 1)),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<double> renderedX() {
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      return chart.data.lineBarsData.single.spots.map((point) => point.x);
    }

    await send([62, 64, 65]);
    expect(renderedX(), orderedEquals([62, 64, 65]));

    await send([0, 1]);
    expect(
      data.points[channelName]!.single.map((point) => point.x),
      orderedEquals([62, 64, 65, 0, 1]),
    );
    expect(renderedX(), orderedEquals([62, 64, 65, 0, 1]));

    await send([1, 2]);
    expect(renderedX(), orderedEquals([62, 64, 65, 0, 1, 1, 2]));

    await tester.pumpWidget(const SizedBox());
    unawaited(stream.close());
  });

  test('periodic array mode retains history under the raw point limit', () {
    const limit = 8 * 1024 * 1024;
    for (final persistent in [false, true]) {
      final data = PlotData(maxDataBytes: limit, purgeSize: 1024 * 1024);
      for (var index = 1; index <= 100; index++) {
        data.filterPoints(
          isTimedScalarData: false,
          isPersistent: persistent,
          isOneShot: false,
          plotChannels: [packet(index)],
          triggerTimestamp: null,
        );
      }
      final history = data.points[channelName]!;
      final samples = history.expand((segment) => segment).length;
      debugPrint(
        'Persistence $persistent: ${history.length} segments, $samples retained samples, ${data.plotMetadata.plotDataBytes} accounted bytes',
      );
      expect(history.length, greaterThan(1));
      expect(data.plotMetadata.plotDataBytes, lessThan(limit));
      expect(data.plotMetadata.plotDataBytes, samples * 24);
    }
  });

  test('persistent segments respect the global render budget', () {
    final cache = FlchartCache();
    cache.spots[channelName] = List.generate(
      400,
      (_) => List.generate(100, (index) => PlottingFlSpot(index.toDouble(), 1)),
    );
    final rendered = cache.reduceSpots();
    final cached = cache.spots[channelName]!
        .expand((segment) => segment)
        .length;
    debugPrint(
      '400 persistent segments: $cached cached spots, $rendered reported render spots',
    );
    expect(rendered, 10000);
    expect(cached, 10000);
  });

  testWidgets('one burst queues one reconnect', (tester) async {
    final service = BurstService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlotWidget(
            daqService: service,
            plotData: PlotData(),
            plotChannels: {
              channelName: ChannelMetadata(channelSetting: ChannelSetting()),
            },
            reconnectionDelayMs: 200,
          ),
        ),
      ),
    );
    expect(service.streams.length, 1);
    for (var i = 0; i < 3; i++) {
      service.streams.first.addError(StateError('synthetic server error'));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800));
    debugPrint(
      'One burst of 3 subscription errors caused ${service.streams.length - 1} retries',
    );
    expect(service.streams.length, 2);
    await tester.pumpWidget(const SizedBox());
    for (final stream in service.streams) {
      unawaited(stream.close());
    }
  });

  testWidgets('the renderer budgets a large persistent waveform history', (
    tester,
  ) async {
    final service = BurstService();
    final data = PlotData();
    final meta = {
      channelName: ChannelMetadata(channelSetting: ChannelSetting()),
    };
    for (var index = 1; index <= 399; index++) {
      data.filterPoints(
        isTimedScalarData: false,
        isPersistent: true,
        isOneShot: false,
        plotChannels: [packet(index, size: 100)],
        triggerTimestamp: null,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlotWidget(
            daqService: service,
            plotData: data,
            plotChannels: meta,
            isPersistent: true,
          ),
        ),
      ),
    );
    service.streams.single.add(reply(400, size: 100));
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.gridData.show, isTrue);
    expect(chart.data.gridData.getDrawingHorizontalLine(0).dashArray, isNull);
    expect(chart.data.gridData.getDrawingVerticalLine(0).dashArray, isNull);
    final rendered = chart.data.lineBarsData.fold(
      0,
      (n, bar) => n + bar.spots.length,
    );
    final cached = data.flchartCache.spots[channelName]!
        .expand((segment) => segment)
        .length;
    expect(data.points[channelName], hasLength(400));
    expect(data.plotMetadata.numberOfPoints, 40000);
    expect(rendered, 10000);
    expect(cached, rendered);
    debugPrint(
      'Persistent waveform history: 40,000 raw spots, $cached cached, $rendered rendered',
    );
    await tester.pumpWidget(const SizedBox());
    unawaited(service.streams.single.close());
  });

  testWidgets('pause buffers by bytes and drains the retained replies once', (
    tester,
  ) async {
    final service = BurstService();
    final data = PlotData(
      maxDataBytes: 8 * 1024 * 1024,
      purgeSize: 1024 * 1024,
    );
    final meta = {
      channelName: ChannelMetadata(channelSetting: ChannelSetting()),
    };
    final completed = <int>[];
    Widget app(bool paused) => MaterialApp(
      home: Scaffold(
        body: PlotWidget(
          daqService: service,
          plotData: data,
          plotChannels: meta,
          isPaused: paused,
          onPlotUpdate: (reply) => completed.add(reply.requestTime.toInt()),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    for (var index = 1; index <= 12; index++) {
      service.streams.single.add(reply(index, size: 100000));
    }
    await tester.pump();
    expect(completed, isEmpty);
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(
      completed,
      orderedEquals([for (var index = 3; index <= 12; index++) index]),
    );
    expect(data.plotMetadata.plotDataBytes, lessThan(8 * 1024 * 1024));
    debugPrint(
      'Pause: retained and replayed 10 recent waveform replies within the 8 MiB budget',
    );
    await tester.pumpWidget(const SizedBox());
    unawaited(service.streams.single.close());
  });
}

class BurstService extends PlotDAQService {
  final streams = <StreamController<PlotReply>>[];

  @override
  Stream<PlotReply> retrievePlot(
    BuildContext context, {
    required Set<String> forChannels,
    int updateDelay = 0,
    int nAcquisitions = 0,
    double? startTime,
    double? endTime,
    int? triggerEvent,
    int? sampleOnEvent,
    String? chXAxis,
    double? waveformDuration,
  }) {
    final stream = StreamController<PlotReply>();
    streams.add(stream);
    return stream.stream;
  }
}
