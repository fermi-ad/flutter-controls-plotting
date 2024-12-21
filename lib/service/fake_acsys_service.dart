import 'package:flutter_controls_core/flutter_controls_core.dart';

class FakeACSysService implements ACSysServiceAPI {
  int startPlotCount = 0;

  int? startPlotnAcquistions;

  @override
  Future<List<DeviceInfo>> getDeviceInfo(List<String> devices) =>
      throw UnimplementedError();

  @override
  Stream<AnalogAlarmStatus> monitorAnalogAlarmProperty(List<String> drfs) =>
      throw UnimplementedError();

  @override
  Stream<Reading> monitorDevices(List<String> drfs) =>
      throw UnimplementedError();

  @override
  Stream<DigitalStatus> monitorDigitalStatusDevices(List<String> devices) =>
      throw UnimplementedError();

  @override
  Stream<Reading> monitorSettingProperty(List<String> drfs) =>
      throw UnimplementedError();

  @override
  Future<SettingStatus> sendCommand(
          {required String toDRF, required String value}) =>
      throw UnimplementedError();

  @override
  Stream<PlotReply> startPlot(List<String> drfs,
      {int? xMin,
      int? xMax,
      int? windowSize,
      int? updateRate,
      int? nAcquisitions,
      int? triggerEvent}) {
    startPlotCount++;

    startPlotnAcquistions = nAcquisitions;

    switch (drfs.first) {
      case "API TEST CONSTANT":
        return Stream<PlotReply>.value(PlotReply(
            plotId: "fake",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: 499,
            windowSize: 500,
            data: [
              PlotChannelData(
                  name: drfs.first,
                  units: "A",
                  status: 0,
                  points: List.generate(
                      500, (i) => PlotPoint(x: i.toDouble(), y: 5.0)))
            ]));

      default:
        return Stream<PlotReply>.value(PlotReply(
            plotId: "fake",
            xAxisUnits: "Index",
            xAxisMin: xMin != null ? xMin.toDouble() : 0,
            xAxisMax: xMax != null ? xMax.toDouble() : 0,
            windowSize: windowSize != null ? 0 : 100,
            data: [
              PlotChannelData(
                  name: drfs.first, units: "", status: -1, points: [])
            ]));
    }
  }

  @override
  Future<SettingStatus> submit(
          {required String forDRF, required DeviceValue newSetting}) =>
      throw UnimplementedError();
}
