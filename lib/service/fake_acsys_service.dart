import 'dart:typed_data';

import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';

class FakeACSysService implements ACSysServiceAPI {
  int startPlotCount = 0;

  int? startPlotnAcquistions;

  @override
  Stream<AnalogAlarmStatus> monitorAnalogAlarmProperty(List<String> drfs) =>
      throw UnimplementedError();

  @override
  Stream<Reading> monitorDevices(
    List<String> drfs, {
    DateTime? endTime,
    DateTime? startTime,
  }) => throw UnimplementedError();

  @override
  Future<Status> sendCommand({required String toDRF, required String value}) =>
      throw UnimplementedError();

  @override
  Stream<PlotReply> startPlot(
    List<String> drfs, {
    double? xMin,
    double? xMax,
    double? startTime,
    double? endTime,
    int? windowSize,
    int? updateRate,
    int? nAcquisitions,
    int? triggerEvent,
    int? sampleOnEvent,
    double? waveformDuration,
    String? chXAxis,
  }) {
    startPlotCount++;

    startPlotnAcquistions = nAcquisitions;

    switch (drfs.first) {
      case "API TEST CONSTANT":
        return Stream<PlotReply>.value(
          PlotReply(
            plotId: "fake",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: 499,
            windowSize: 500,
            requestTime: 0.0,
            data: [
              PlotChannelData(
                name: drfs.first,
                units: "A",
                rate: getRate(updateRate),
                status: 0,
                points: [
                  PlotPoint(
                    t: getCurrentAcsysEpochTime(),
                    value: DevScalarArray(
                      Float64List.fromList(List.generate(500, (i) => 5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return Stream<PlotReply>.value(
          PlotReply(
            plotId: "fake",
            xAxisUnits: "Index",
            xAxisMin: xMin != null ? xMin.toDouble() : 0,
            xAxisMax: xMax != null ? xMax.toDouble() : 0,
            windowSize: windowSize != null ? 0 : 100,
            requestTime: 0.0,
            data: [
              PlotChannelData(
                name: drfs.first,
                units: "",
                rate: getRate(updateRate),
                status: -1,
                points: [],
              ),
            ],
          ),
        );
    }
  }

  @override
  Future<Status> submit({
    required String forDRF,
    required DeviceValue newSetting,
  }) => throw UnimplementedError();

  @override
  Future<List<PlotConfigurationListing>> listPlotConfigurations() {
    // N/A for plotting lib
    throw UnimplementedError();
  }

  @override
  Future<void> removePlotConfiguration({
    required PlotConfigId configurationId,
  }) {
    // N/A for plotting lib
    throw UnimplementedError();
  }

  @override
  Future<PlotConfigurationSnapshot> retrieveLastUserConfiguration() {
    throw UnimplementedError();
  }

  @override
  Future<PlotConfigurationSnapshot> retrievePlotConfiguration({
    required PlotConfigId configurationId,
  }) {
    // N/A for plotting lib
    throw UnimplementedError();
  }

  @override
  Future<PlotConfigurationSnapshot> savePlotConfiguration({
    required PlotConfigurationSnapshot snapshot,
  }) {
    // N/A for plotting lib
    throw UnimplementedError();
  }

  @override
  Future<void> saveUserConfiguration({
    required PlotConfigurationSnapshot snapshot,
    String? user,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Reading>> readDevices(List<String> devices) {
    throw UnimplementedError();
  }

  @override
  Stream<Alarm> monitorAlarms() {
    throw UnimplementedError();
  }

  @override
  Future<List<Alarm>> getAlarmsSnapshot() {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }
}
