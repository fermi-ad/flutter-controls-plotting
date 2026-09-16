/// Acquisition settings used by the stream-driven device bar chart.
class BarAcquisitionOptions {
  final int updateDelay;
  final int nAcquisitions;
  final int? triggerEvent;
  final int? sampleOnEvent;
  final double? startTime;
  final double? endTime;

  const BarAcquisitionOptions({
    this.updateDelay = 0,
    this.nAcquisitions = 0,
    this.triggerEvent,
    this.sampleOnEvent,
    this.startTime,
    this.endTime,
  });
}
