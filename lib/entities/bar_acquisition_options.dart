/// Immutable acquisition settings for a stream-driven device bar chart.
///
/// The widget forwards these values unchanged to the DAQ service when starting
/// a subscription. The service determines supported combinations and validates
/// them; constructing these options does not start acquisition or validate them.
class BarAcquisitionOptions {
  /// Requested update interval in microseconds.
  ///
  /// Zero uses the service's default acquisition behavior, not necessarily a
  /// continuously refreshing stream. Use a positive interval for periodic
  /// updates when supported by the service.
  final int updateDelay;

  /// Requested acquisition count, or zero for no explicit count limit.
  ///
  /// The count is interpreted by the service, not as a limit on chart rebuilds
  /// or stream replies. The standard service maps zero to an unspecified count.
  final int nAcquisitions;

  /// Optional event identifier used to trigger acquisition.
  ///
  /// Supported event identifiers and trigger behavior are service-dependent.
  final int? triggerEvent;

  /// Optional event identifier on which to sample instead of periodic sampling.
  ///
  /// Supported events and interaction with [updateDelay] are service-dependent.
  final int? sampleOnEvent;

  /// Optional acquisition start time in the service's epoch-seconds convention.
  ///
  /// The standard service uses ACSys epoch time for archived or scheduled data.
  final double? startTime;

  /// Optional acquisition end time in the same convention as [startTime].
  ///
  /// When omitted, no explicit end time is forwarded to the service.
  final double? endTime;

  /// Creates acquisition options using the service defaults unless overridden.
  const BarAcquisitionOptions({
    this.updateDelay = 0,
    this.nAcquisitions = 0,
    this.triggerEvent,
    this.sampleOnEvent,
    this.startTime,
    this.endTime,
  });
}
