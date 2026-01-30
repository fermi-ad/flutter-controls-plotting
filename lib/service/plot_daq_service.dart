import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

abstract class PlotDAQService {
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
  });
}

class StandardPlotDAQ implements PlotDAQService {
  StandardPlotDAQ();

  double? firstScalarRampEpochTime;
  double? firstScalarRandRampEpochTime;
  double? repetetiveScalarPlotEpochTime;

  double? timeOfLastIntermittentError;
  final double minTimeSinceLastError = 10;
  int currentConsecutiveErrorCount = 0;
  int maxConsecutiveErrors = 1;

  int? eventAcquisitionCount;
  int? eventAcquisitionLimit;

  // Test variables
  int scalarRampCount = 0;
  int statusIntErrorCount = 0;
  int tclkEvent00Duration = 2;
  int tclkEvent10Duration = 5;
  int tclkEvent20Duration = 10;
  int? scalarRampCountLimit;
  final int oneSecondDelay = 1000000;

  int maxUpdateDelay = 333333;

  int? limitAcquisitionMs;

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
  }) {
    var plotArgs = _PlotArgs(xMin: 0, xMax: 499, windowSize: 500);
    final channels = _separateChannels(forChannels);

    if (channels.mockChannels.isNotEmpty) {
      return _retrieveInternalPlot(
        context,
        forChannels: forChannels,
        args: plotArgs,
        updateDelay: updateDelay,
        startTime: startTime,
        endTime: endTime,
        triggerEvent: triggerEvent,
        sampleOnEvent: sampleOnEvent,
        nAcquisitions: nAcquisitions == 0 ? null : nAcquisitions,
        chXAxis: chXAxis,
      );
    } else {
      // API only
      return ACSys.api(context).startPlot(
        forChannels.toList(),
        xMin: plotArgs.xMin,
        xMax: plotArgs.xMax,
        startTime: startTime,
        endTime: endTime,
        windowSize: plotArgs.windowSize,
        updateRate: updateDelay,
        triggerEvent: triggerEvent,
        sampleOnEvent: sampleOnEvent,
        nAcquisitions: nAcquisitions == 0 ? null : nAcquisitions,
        chXAxis: chXAxis,
      );
    }
  }

  Stream<PlotReply> _retrieveInternalPlot(
    BuildContext context, {
    required Set<String> forChannels,
    required _PlotArgs args,
    int updateDelay = 0,
    int? nAcquisitions,
    double? startTime,
    double? endTime,
    int? sampleOnEvent,
    int? triggerEvent,
    String? chXAxis,
  }) async* {
    var requestTime = getCurrentAcsysEpochTime();
    if (updateDelay == 0 && sampleOnEvent == null) {
      // No refresh cycle, attempt to combine gen plots with api results
      var generatePlotFuture = _generatePlot(
        forChannels: forChannels,
        args: args,
        rate: getRate(updateDelay),
        requestTime: requestTime,
        chXAxis: chXAxis,
      );

      // Separate channels into mock and API categories
      final channels = _separateChannels(forChannels);

      if (channels.apiChannels.isNotEmpty) {
        // Internal and API request
        var apiStream = ACSys.api(context).startPlot(
          channels.apiChannels,
          xMin: args.xMin,
          xMax: args.xMax,
          windowSize: args.windowSize,
        );

        var generatePlot = await generatePlotFuture;

        var apiResponse = apiStream.first;

        apiResponse.then((PlotReply value) {
          generatePlot.data.addAll(value.data);
        });

        yield generatePlot;
      } else {
        yield await generatePlotFuture;
      }
    } else {
      // Mock event-driven updates.
      if (sampleOnEvent != null) {
        if (sampleOnEvent == plotEvent00) {
          updateDelay = tclkEvent00Duration * oneSecondDelay;
        } else if (sampleOnEvent == plotEvent10) {
          updateDelay = tclkEvent10Duration * oneSecondDelay;
        } else if (sampleOnEvent == plotEvent20) {
          updateDelay = tclkEvent20Duration * oneSecondDelay;
        }
      }
      // Verify if archiver request
      if (startTime != null) {
        var pointsProcessed = 0;
        while (true) {
          var archivedPlotMetadata = await _generateArchivedPlot(
            forChannels: forChannels,
            startTime: startTime,
            endTime: endTime,
            args: args,
            pointsProcessed: pointsProcessed,
            requestTime: requestTime,
            apiDelay: updateDelay,
            chXAxis: chXAxis,
          );

          var reply = archivedPlotMetadata.currentPlotReply;
          if (reply == null) {
            break;
          }

          yield reply;

          pointsProcessed = archivedPlotMetadata.pointsProcessed;

          await Future.delayed(Duration.zero);
        }

        if (endTime != null && getCurrentAcsysEpochTime() > endTime) {
          return;
        }

        // wait for future plot
        while (getCurrentAcsysEpochTime() < startTime) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Refresh cycle only API provided.
      bool validLoop = true;
      int nAcquisitionsInLoop = 0;
      int eventDuration = 0;

      // Calculate event if appliable
      if (triggerEvent != null &&
          (triggerEvent == plotEvent00 ||
              triggerEvent == plotEvent10 ||
              triggerEvent == plotEvent20)) {
        eventAcquisitionCount = 0;

        // Points per second.
        double pointLimitCalc = 1000000 / updateDelay;
        // Total points for event duration
        if (triggerEvent == plotEvent00) {
          eventDuration = tclkEvent00Duration;
        } else if (triggerEvent == plotEvent10) {
          eventDuration = tclkEvent10Duration;
        } else if (triggerEvent == plotEvent20) {
          eventDuration = tclkEvent20Duration;
        }
        pointLimitCalc = pointLimitCalc * eventDuration;

        eventAcquisitionLimit = pointLimitCalc.floor();
      }

      // Set up fake acquisition with max delay.
      var itterationPointCount = 1;
      var apiDelay = 0;

      bool array = true;
      for (String chName in forChannels) {
        if (chName.contains("SCALAR")) {
          array = false;
          break;
        }
      }

      // Update delay is smaller than max stream update delay.
      if (!array && maxUpdateDelay > updateDelay) {
        itterationPointCount = (maxUpdateDelay / updateDelay).floor();
        apiDelay = updateDelay;
      }

      String rate = getRate(updateDelay);

      Stopwatch? acquisitionStopwatch;
      if (limitAcquisitionMs != null) {
        acquisitionStopwatch = Stopwatch();
        acquisitionStopwatch.start();
      }
      while (validLoop) {
        if (apiDelay == 0) {
          await Future.delayed(Duration(microseconds: updateDelay));
        }

        var pointCount = itterationPointCount;

        if (nAcquisitions != null) {
          if (nAcquisitionsInLoop + pointCount > nAcquisitions) {
            // Fetch the rest of points.
            pointCount = nAcquisitions - nAcquisitionsInLoop;
          }
        }

        List<double>? eventXList;
        int itrPointCount = pointCount;

        for (var i = 0; i < pointCount; i++) {
          if (triggerEvent != null && eventAcquisitionCount != null) {
            eventXList ??= [];
            eventXList.add(
              (eventDuration * eventAcquisitionCount!) /
                  (eventAcquisitionLimit!),
            );

            if (eventAcquisitionCount == eventAcquisitionLimit) {
              eventAcquisitionCount = 0;
              itrPointCount = i + 1;
              break;
            } else {
              eventAcquisitionCount = eventAcquisitionCount! + 1;
            }
          }
        }

        var plot = await _generatePlot(
          forChannels: forChannels,
          requestTime: requestTime,
          rate: rate,
          apiDelay: apiDelay,
          pointCount: itrPointCount,
          args: args,
          markChannelNameErrors: true,
          eventXList: eventXList,
          chXAxis: chXAxis,
        );

        validLoop = false;
        for (var channel in plot.data) {
          if (channel.points.isNotEmpty) {
            // Atleast one channel has points.
            validLoop = true;
          }
        }

        nAcquisitionsInLoop += pointCount;
        if (nAcquisitions != null && nAcquisitionsInLoop == nAcquisitions) {
          validLoop = false;
        }

        if (limitAcquisitionMs != null) {
          var msSinceStart = acquisitionStopwatch!.elapsedMilliseconds;
          if (limitAcquisitionMs! <= msSinceStart) {
            validLoop = false;
          }
        }

        // If end time is specified end the acquisition once the end time is reached.
        if (endTime != null && getCurrentAcsysEpochTime() >= endTime) {
          validLoop = false;
        }

        yield plot;
      }
    }
  }

  Future<ArchivedPlotReplyMetadata> _generateArchivedPlot({
    required Set<String> forChannels,
    required double startTime,
    required double? endTime,
    required _PlotArgs args,
    required int apiDelay,
    int pointsPerReply = 1000,
    int pointsProcessed = 0,
    String? chXAxis,
    required double requestTime,
  }) async {
    var rate = getRate(apiDelay);

    endTime ??= getCurrentAcsysEpochTime();

    if (endTime > requestTime) {
      endTime = requestTime;
    }

    if (startTime > requestTime) {
      startTime = requestTime;
    }

    var totalDuration = endTime - startTime;
    double secondsPerPoint = apiDelay / 1e6;
    var pointsPerSecond = 1 / secondsPerPoint;

    var pointsInTotalDuration = (totalDuration * pointsPerSecond).ceil();

    var pointsLeft = (pointsInTotalDuration - pointsProcessed);

    if (pointsLeft == 0) {
      return ArchivedPlotReplyMetadata(
        currentPlotReply: null,
        pointsProcessed: pointsProcessed,
      );
    }

    if (pointsLeft < pointsPerReply) {
      pointsPerReply = pointsLeft;
    }

    var calulatedStartTime = startTime + (pointsProcessed * secondsPerPoint);

    var result = await _generatePlot(
      forChannels: forChannels,
      args: args,
      apiDelay: apiDelay,
      requestTime: requestTime,
      pointCount: pointsPerReply,
      currentEpochTime: calulatedStartTime,
      rate: rate,
      chXAxis: chXAxis,
      noDelay: true,
    );

    pointsProcessed += pointsPerReply;
    return ArchivedPlotReplyMetadata(
      currentPlotReply: result,
      pointsProcessed: pointsProcessed,
    );
  }

  // Separates channels into mock channels and API channels
  _Channels _separateChannels(Set<String> forChannels) {
    List<String> apiChannels = [];
    Set<String> mockChannels = {};

    for (var channel in forChannels) {
      bool isMockChannel = false;

      // Check if this channel is a mock channel (GenPlot)
      for (var genChannel in GenPlots.values) {
        if (genChannel.name == channel) {
          mockChannels.add(channel);
          isMockChannel = true;
          break;
        }
      }

      // If not a mock channel, it's an API channel
      if (!isMockChannel) {
        apiChannels.add(channel);
      }
    }

    return _Channels(mockChannels: mockChannels, apiChannels: apiChannels);
  }

  Future<PlotReply> _generatePlot({
    required Set<String> forChannels,
    required _PlotArgs args,
    required double requestTime,
    required String rate,
    int apiDelay = 0,
    int pointCount = 1,
    bool markChannelNameErrors = false,
    List<double>? eventXList,
    // Optional parameter used for fetching "archived" data.
    double? currentEpochTime,
    bool noDelay = false,
    String? chXAxis,
  }) async {
    var totalDuration = (apiDelay * pointCount);

    List<PlotChannelData> internalDaqData = [];
    var xAxisUnits = 'Index';

    currentEpochTime ??= getCurrentAcsysEpochTime();
    double secondsPerPoint = apiDelay / 1e6;

    // Generate x axis values for set. for maximum possible frequency for request.
    List<double>? xAxisData;
    if (chXAxis != null) {
      xAxisUnits = chXAxis;
      xAxisData = [];
      double xAxisTime = currentEpochTime;
      for (int i = 0; i < pointCount; i++) {
        var (unit, points) = _generateData(
          forChannel: chXAxis,
          currentEpochTime: xAxisTime,
          xAxisUnits: xAxisUnits,
          xAxisValue: null,
          eventX: eventXList?[i],
        );
        if (points != null && points.isNotEmpty) {
          if (points.isNotEmpty && points.first.value is DevScalar) {
            xAxisData.add((points.first.value as DevScalar).value);
          } else {
            throw Exception('Invalid x-axis channel data.');
          }
        }
        xAxisTime += secondsPerPoint;
      }
    }

    for (var forChannel in forChannels) {
      // Reset Time for next channel.
      var chEpochTime = currentEpochTime;

      // Set variables that may be specific to the channel.
      var chRate = rate;
      var chPoints = pointCount;
      var chSecondsPerPoint = secondsPerPoint;

      // Override values if channel has special configuration.
      for (var genPlot in GenPlots.values) {
        if (genPlot.name != forChannel) {
          continue;
        }

        if (genPlot.minUpdateDelay != null) {
          // Calculate max number of points for this rate and total duration
          var maxPointsForRate = (totalDuration / genPlot.minUpdateDelay!)
              .floor();
          if (chPoints > maxPointsForRate) {
            chPoints = maxPointsForRate;
            chSecondsPerPoint = genPlot.minUpdateDelay! / 1e6;
            chRate = getRate(genPlot.minUpdateDelay);
          }
        }
        break;
      }

      for (int i = 0; i < chPoints; i++) {
        double? xAxisValue;
        if (xAxisData != null) {
          if (chPoints == pointCount) {
            xAxisValue = xAxisData[i];
          } else {
            // Find nearest x axis index.
            var indexRatio = pointCount / chPoints;
            var xAxisIndex = (i * indexRatio).floor();
            while (xAxisIndex >= xAxisData.length) {
              xAxisIndex = xAxisData.length - 1;
            }
            xAxisValue = xAxisData[xAxisIndex];
          }
        }
        List<PlotPoint>? data;
        (xAxisUnits, data) = _generateData(
          forChannel: forChannel,
          currentEpochTime: chEpochTime,
          xAxisUnits: xAxisUnits,
          xAxisValue: xAxisValue,
          eventX: eventXList?[i],
        );

        // Verify if plotChannelData already exists
        bool newChannelAdded = false;
        var existingChannelData = internalDaqData.firstWhere(
          (channelData) => channelData.name == forChannel,
          orElse: () {
            PlotChannelData newChannel;
            if (data != null) {
              newChannel = PlotChannelData(
                name: forChannel,
                rate: chRate,
                units: "V",
                points: data,
              );
            } else {
              String? statusString;
              int status = -1;

              if (forChannel == GenPlots.statusError.name) {
                statusString = "Generated Error Message Channel";
                status = 123;
              } else if (forChannel == GenPlots.statusIntError.name) {
                statusString = "Intermittent connection simulation channel";
                status = 456;
              }

              newChannel = PlotChannelData(
                name: forChannel,
                rate: chRate,
                units: "",
                status: status,
                statusString: statusString,
              );
            }
            internalDaqData.add(newChannel);
            newChannelAdded = true;
            return newChannel;
          },
        );

        if (data != null) {
          if (!newChannelAdded) {
            existingChannelData.points.addAll(data);
          }
          args.xMax = max(args.xMax, data.length - 1);
          args.windowSize = max(args.windowSize, data.length);
        }
        chEpochTime += chSecondsPerPoint;
      }
    }

    if (!noDelay) {
      Duration duration = Duration(microseconds: totalDuration);
      await Future.delayed(duration);
    }

    double? triggerTimestamp;

    if (eventXList != null && eventXList.isNotEmpty) {
      triggerTimestamp = currentEpochTime - eventXList.last;
    }

    var generatedPlotReply = PlotReply(
      plotId: "Internal",
      triggerTimestamp: triggerTimestamp,
      requestTime: requestTime,
      xAxisUnits: xAxisUnits,
      xAxisMin: args.xMin + 0.0,
      xAxisMax: args.xMax + 0.0,
      windowSize: args.windowSize,
      data: internalDaqData,
    );

    return generatedPlotReply;
  }

  (String, List<PlotPoint>?) _generateData({
    required String forChannel,
    required double currentEpochTime,
    required String xAxisUnits,
    required double? xAxisValue,
    required double? eventX,
  }) {
    List<PlotPoint>? data;
    if (forChannel == GenPlots.constant.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(List.generate(500, (i) => 5)),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.randConst.name) {
      var rand = Random();
      var constant = rand.nextInt(25);
      data = [
        PlotPoint(
          value: DevScalarArray(List.generate(500, (i) => constant.toDouble())),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.ramp.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(List.generate(500, (i) => i.toDouble())),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.randRamp.name) {
      var rand = Random();
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(500, (i) => i + (rand.nextInt(50) - 25)),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.scalarRamp.name ||
        forChannel == GenPlots.slowScalarRamp.name) {
      firstScalarRampEpochTime ??= currentEpochTime;
      if (scalarRampCountLimit != null &&
          scalarRampCount >= scalarRampCountLimit!) {
        data = [];
      } else {
        scalarRampCount += 1;
        var difference = currentEpochTime - firstScalarRampEpochTime!;

        var x = eventX ?? currentEpochTime;
        if (xAxisValue != null) {
          data = [
            PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, difference)])),
          ];
        } else {
          xAxisUnits = 'Time';
          data = [PlotPoint(value: DevScalar(difference), t: x)];
        }
      }
    } else if (forChannel == GenPlots.scalarRandRamp.name) {
      var rand = Random();

      firstScalarRandRampEpochTime ??= currentEpochTime;
      var value = currentEpochTime - firstScalarRandRampEpochTime!;

      value = value + (rand.nextInt(50) - 25);

      var x = eventX ?? currentEpochTime;

      if (xAxisValue != null) {
        data = [
          PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
        ];
      } else {
        xAxisUnits = 'Time';
        data = [PlotPoint(value: DevScalar(value), t: x)];
      }
    } else if (forChannel == GenPlots.scalarSquare.name) {
      repetetiveScalarPlotEpochTime ??= currentEpochTime;
      var difference = currentEpochTime - repetetiveScalarPlotEpochTime!;
      double value = calculateSquareByDifference(difference);

      var x = eventX ?? currentEpochTime;
      if (xAxisValue != null) {
        data = [
          PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
        ];
      } else {
        xAxisUnits = 'Time';
        data = [PlotPoint(value: DevScalar(value), t: x)];
      }
    } else if (forChannel == GenPlots.scalarTriangle.name) {
      repetetiveScalarPlotEpochTime ??= currentEpochTime;
      var difference = currentEpochTime - repetetiveScalarPlotEpochTime!;
      var period = 4.0; // 4 second period
      var phase = (difference % period) / period;
      var value = phase < 0.5
          ? 20.0 * (2.0 * phase) - 10.0
          : 20.0 * (2.0 - 2.0 * phase) - 10.0;

      var x = eventX ?? currentEpochTime;
      if (xAxisValue != null) {
        data = [
          PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
        ];
      } else {
        xAxisUnits = 'Time';
        data = [PlotPoint(value: DevScalar(value), t: x)];
      }
    } else if (forChannel == GenPlots.scalarSawtooth.name) {
      repetetiveScalarPlotEpochTime ??= currentEpochTime;
      var difference = currentEpochTime - repetetiveScalarPlotEpochTime!;
      double value = calculateSawtoothByDifference(difference);

      var x = eventX ?? currentEpochTime;
      if (xAxisValue != null) {
        data = [
          PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
        ];
      } else {
        xAxisUnits = 'Time';
        data = [PlotPoint(value: DevScalar(value), t: x)];
      }
    } else if (forChannel == GenPlots.scalarSine.name ||
        forChannel == GenPlots.scalarSineIntermittent.name) {
      repetetiveScalarPlotEpochTime ??= currentEpochTime;
      var difference = currentEpochTime - repetetiveScalarPlotEpochTime!;
      double value = calculateSineByDifference(difference);

      if (forChannel == GenPlots.scalarSineIntermittent.name) {
        bool exception = false;
        if (currentConsecutiveErrorCount > 0 &&
            currentConsecutiveErrorCount < maxConsecutiveErrors) {
          // Finish all the consecutive errors.
          currentConsecutiveErrorCount++;
          exception = true;
        }
        if (value >= 1 && value <= 2) {
          // Error should be thrown on first try.
          var timeSinceLastError = timeOfLastIntermittentError != null
              ? currentEpochTime - timeOfLastIntermittentError!
              : minTimeSinceLastError;
          if (timeSinceLastError >= minTimeSinceLastError) {
            currentConsecutiveErrorCount = 1;
            timeOfLastIntermittentError = currentEpochTime;
            exception = true;
          }
        }
        if (exception) {
          throw Exception(
            'Intermittent Error at $value (consecutive: $currentConsecutiveErrorCount/$maxConsecutiveErrors)',
          );
        }
        currentConsecutiveErrorCount = 0;
      }

      var x = eventX ?? currentEpochTime;
      if (xAxisValue != null) {
        data = [
          PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
        ];
      } else {
        xAxisUnits = 'Time';
        data = [PlotPoint(value: DevScalar(value), t: x)];
      }
    } else if (forChannel == GenPlots.parabola.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(501, (i) => pow(i - 250, 2).toDouble()),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.parabola64k.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(65535, (i) => pow(i - 32767, 2).toDouble()),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.parabola32k.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(32767, (i) => pow(i - 16383, 2).toDouble()),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.sine.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(501, (i) => sin((i - 250) / 500 * 6.28).toDouble()),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.sine64k.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(
              65535,
              (i) => ((sin((i - 32767) / 65535 * 6.28) + 1) / 2 * 1073676289)
                  .toDouble(),
            ),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.sine32k.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(
              32767,
              (i) => ((sin((i - 16383) / 32767 * 6.28) + 1) / 2 * 268402689)
                  .toDouble(),
            ),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.normal.name) {
      data = [
        PlotPoint(
          value: DevScalarArray(
            List.generate(
              500,
              (i) =>
                  (pow(500, 2) / 4) *
                  pow(e, -(pow(i - 250, 2) / (2 * pow(50, 2)))).toDouble() /
                  (50 * sqrt(2 * pi)),
            ),
          ),
          t: currentEpochTime,
        ),
      ];
    } else if (forChannel == GenPlots.statusError.name) {
      // This channel will return null data to trigger status error
      data = null;
    } else if (forChannel == GenPlots.statusIntError.name) {
      // This channel alternates between returning a value and null (intermittent error)
      statusIntErrorCount++;
      if (statusIntErrorCount % 2 == 0) {
        // Return null on even counts to simulate intermittent connection error
        data = null;
      } else {
        // Return a value on odd counts (alternating 0 and 1)
        var value = ((statusIntErrorCount / 2).floor() % 2).toDouble();
        var x = eventX ?? currentEpochTime;
        if (xAxisValue != null) {
          data = [
            PlotPoint(t: x, value: DevTimeSeries([(xAxisValue, value)])),
          ];
        } else {
          xAxisUnits = 'Time';
          data = [PlotPoint(value: DevScalar(value), t: x)];
        }
      }
    }
    return (xAxisUnits, data);
  }
}

double calculateSawtoothByDifference(double difference) {
  var period = 3.0; // 3 second period
  var phase = (difference % period) / period;
  var value = 20.0 * phase - 10.0;
  return value;
}

double calculateSineByDifference(double difference) {
  var period = 2.0; // 2 second period
  var phase = (difference % period) / period;
  var value = 10.0 * sin(phase * 2 * pi);
  return value;
}

double calculateSquareByDifference(double difference) {
  var period = 2.0; // 2 second period
  var phase = (difference % period) / period;
  var value = phase < 0.5 ? 10.0 : -10.0;
  return value;
}

double getCurrentAcsysEpochTime() {
  DateTime now = DateTime.now();
  return now.millisecondsSinceEpoch / 1000;
}

// Facilitates passing plot arguments by reference for generation of plot from API and local.
class _PlotArgs {
  double xMin;
  double xMax;
  int windowSize;

  _PlotArgs({required this.xMin, required this.xMax, required this.windowSize});
}

class ArchivedPlotReplyMetadata {
  PlotReply? currentPlotReply;
  int pointsProcessed;

  ArchivedPlotReplyMetadata({
    required this.currentPlotReply,
    required this.pointsProcessed,
  });
}

// Helper class to separate mock channels from API channels
class _Channels {
  final Set<String> mockChannels;
  final List<String> apiChannels;

  _Channels({required this.mockChannels, required this.apiChannels});
}

enum GenPlots {
  constant("PLOT TEST CONSTANT"),
  randConst("PLOT TEST RAND CONSTANT"),
  ramp("PLOT TEST RAMP"),
  randRamp("PLOT TEST RAND RAMP"),
  scalarRamp("PLOT TEST SCALAR RAMP"),
  slowScalarRamp("PLOT TEST SLOW SCALAR RAMP", minUpdateDelay: 50000),
  scalarRandRamp("PLOT TEST SCALAR RAND RAMP"),
  scalarSine("PLOT TEST SCALAR SINE"),
  scalarSineIntermittent("PLOT TEST SCALAR INT SINE"),
  scalarSquare("PLOT TEST SCALAR SQUARE"),
  scalarTriangle("PLOT TEST SCALAR TRIANGLE"),
  scalarSawtooth("PLOT TEST SCALAR SAWTOOTH"),
  parabola("PLOT TEST PARABOLA"),
  parabola64k("PLOT TEST PARABOLA 64K"),
  parabola32k("PLOT TEST PARABOLA 32K"),
  sine("PLOT TEST SINE"),
  sine64k("PLOT TEST SINE 64K"),
  sine32k("PLOT TEST SINE 32K"),
  normal("PLOT TEST NORMAL"),
  statusError("PLOT TEST STATUS ERROR"),
  statusIntError("PLOT TEST STATUS INT ERROR");

  const GenPlots(this.name, {this.minUpdateDelay});
  final String name;
  final int? minUpdateDelay;
}

const int plotEvent00 = 0;
const int plotEvent10 = 16;
const int plotEvent20 = 32;

bool channelHasError(PlotChannelData chData) {
  return chData.status != 0;
}

bool channelHasErrorOrNoPoints(PlotChannelData chData) {
  return channelHasError(chData) || chData.points.isEmpty;
}

String parseDaqTimeAsString(double value, {bool showMillis = false}) {
  var msSinceEpoch = value * 1000;
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch.toInt());
  var h = dateTime.hour;
  var m = dateTime.minute;
  var s = dateTime.second;
  var ms = dateTime.millisecond;
  var hour = h.toString().padLeft(2, '0');
  var minute = m.toString().padLeft(2, '0');
  var second = s.toString().padLeft(2, '0');
  var millis = ms.toString().padLeft(3, '0');

  return showMillis ? '$hour:$minute:$second.$millis' : '$hour:$minute:$second';
}

String getRate(int? updateDelay) {
  if (updateDelay == null || updateDelay == 0) {
    return "";
  }

  if (updateDelay < 0) {
    return "Unknown";
  }

  double frequencyHz = 1e6 / updateDelay;
  return "${frequencyHz.floor()} Hz";
}
