import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

abstract class PlotDAQService {
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required Set<String> forChannels,
      int updateDelay = 0,
      int nAcquisitions = 0,
      int? triggerEvent});
}

class StandardPlotDAQ implements PlotDAQService {
  StandardPlotDAQ();

  double? firstScalarRampEpochTime;
  double? firstScalarRandRampEpochTime;

  int? eventAcquisitionCount;
  int? eventAcquisitionLimit;

  // Test variables
  int scalarRampCount = 0;
  int scalarRampEventDuration = 10;
  int? scalarRampCountLimit;

  int maxUpdateDelay = 333333;

  int? limitAcquisitionMs;

  @override
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required Set<String> forChannels,
      int updateDelay = 0,
      int nAcquisitions = 0,
      int? triggerEvent}) {
    var containsGenPlots = false;
    var plotArgs = _PlotArgs(xMin: 0, xMax: 499, windowSize: 500);
    for (var genChannel in GenPlots.values) {
      if (forChannels.contains(genChannel.name)) {
        containsGenPlots = true;
        break;
      }
    }

    if (containsGenPlots) {
      return _retrieveInternalPlot(context,
          forChannels: forChannels,
          args: plotArgs,
          updateDelay: updateDelay,
          triggerEvent: triggerEvent,
          nAcquisitions: nAcquisitions == 0 ? null : nAcquisitions);
    } else {
      // API only
      return ACSys.api(context).startPlot(forChannels.toList(),
          xMin: plotArgs.xMin,
          xMax: plotArgs.xMax,
          windowSize: plotArgs.windowSize,
          updateRate: updateDelay,
          triggerEvent: triggerEvent,
          nAcquisitions: nAcquisitions == 0 ? null : nAcquisitions);
    }
  }

  Stream<PlotReply> _retrieveInternalPlot(BuildContext context,
      {required Set<String> forChannels,
      required _PlotArgs args,
      int updateDelay = 0,
      int? nAcquisitions,
      int? triggerEvent}) async* {
    var requestTime = getCurrentAcsysEpochTime();
    if (updateDelay == 0) {
      // No refresh cycle, attempt to combine gen plots with api results
      var generatePlotFuture = _generatePlot(
          forChannels: forChannels,
          args: args,
          rate: getRate(updateDelay),
          requestTime: requestTime);

      // Verify if any apiChannels provided
      List<String> apiChannels = [];
      apiChannels.addAll(forChannels);
      for (var genChannel in GenPlots.values) {
        if (forChannels.contains(genChannel.name)) {
          apiChannels.remove(genChannel.name);
        }
      }

      if (apiChannels.isNotEmpty) {
        // Internal and API request
        var apiStream = ACSys.api(context).startPlot(apiChannels,
            xMin: args.xMin, xMax: args.xMax, windowSize: args.windowSize);

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
      // Refresh cycle only API provided.
      bool validLoop = true;
      int nAcquisitionsInLoop = 0;

      // Calculate event if appliable
      if (triggerEvent != null && triggerEvent == plotEvent) {
        eventAcquisitionCount = 0;

        // Points per second.
        double pointLimitCalc = 1000000 / updateDelay;
        // Total points for event duration
        pointLimitCalc = pointLimitCalc * scalarRampEventDuration;

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

        for (var i = 0; i < pointCount; i++) {
          if (triggerEvent != null && eventAcquisitionCount != null) {
            eventXList ??= [];
            eventXList.add((scalarRampEventDuration * eventAcquisitionCount!) /
                (eventAcquisitionLimit!));

            if (eventAcquisitionCount == eventAcquisitionLimit) {
              eventAcquisitionCount = 0;
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
            pointCount: pointCount,
            args: args,
            markChannelNameErrors: true,
            eventXList: eventXList);

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

        yield plot;
      }
    }
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
  }) async {
    var totalDuration = (apiDelay * pointCount);

    List<PlotChannelData> internalDaqData = [];
    var xAxisUnits = 'Index';

    var currentEpochTime = getCurrentAcsysEpochTime();
    double secondsPerPoint = apiDelay / 1e6;

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
          var maxPointsForRate =
              (totalDuration / genPlot.minUpdateDelay!).floor();
          if (chPoints > maxPointsForRate) {
            chPoints = maxPointsForRate;
            chSecondsPerPoint = genPlot.minUpdateDelay! / 1e6;
            chRate = getRate(genPlot.minUpdateDelay);
          }
        }
        break;
      }

      for (int i = 0; i < chPoints; i++) {
        List<PlotPoint>? data;
        (xAxisUnits, data) = _generateData(
            forChannel: forChannel,
            currentEpochTime: chEpochTime,
            xAxisUnits: xAxisUnits,
            eventX: eventXList?[i]);

        // Verify if plotChannelData already exists
        bool newChannelAdded = false;
        var existingChannelData = internalDaqData.firstWhere(
            (channelData) => channelData.name == forChannel, orElse: () {
          PlotChannelData newChannel;
          if (data != null) {
            newChannel = PlotChannelData(
                name: forChannel, rate: chRate, units: "V", points: data);
          } else {
            newChannel = PlotChannelData(
                name: forChannel, rate: chRate, units: "", status: -1);
          }
          internalDaqData.add(newChannel);
          newChannelAdded = true;
          return newChannel;
        });

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

    Duration duration = Duration(microseconds: totalDuration);
    await Future.delayed(duration);

    var generatedPlotReply = PlotReply(
        plotId: "Internal",
        requestTime: requestTime,
        xAxisUnits: xAxisUnits,
        xAxisMin: args.xMin + 0.0,
        xAxisMax: args.xMax + 0.0,
        windowSize: args.windowSize,
        data: internalDaqData);

    return generatedPlotReply;
  }

  (String, List<PlotPoint>?) _generateData(
      {required String forChannel,
      required double currentEpochTime,
      required String xAxisUnits,
      required double? eventX}) {
    List<PlotPoint>? data;
    if (forChannel == GenPlots.constant.name) {
      data = List.generate(
          500, (i) => PlotPoint(x: i.toDouble(), y: 5.0, t: currentEpochTime));
    } else if (forChannel == GenPlots.randConst.name) {
      var rand = Random();
      var constant = rand.nextInt(25);
      data = List.generate(
          500,
          (i) => PlotPoint(
              x: i.toDouble(), y: constant.toDouble(), t: currentEpochTime));
    } else if (forChannel == GenPlots.ramp.name) {
      data = List.generate(
          500,
          (i) =>
              PlotPoint(x: i.toDouble(), y: i.toDouble(), t: currentEpochTime));
    } else if (forChannel == GenPlots.randRamp.name) {
      var rand = Random();
      data = List.generate(
          500,
          (i) => PlotPoint(
              x: i.toDouble(),
              y: i.toDouble() + (rand.nextInt(50) - 25),
              t: currentEpochTime));
    } else if (forChannel == GenPlots.scalarRamp.name ||
        forChannel == GenPlots.slowScalarRamp.name) {
      firstScalarRampEpochTime ??= currentEpochTime;
      if (scalarRampCountLimit != null &&
          scalarRampCount >= scalarRampCountLimit!) {
        data = [];
      } else {
        scalarRampCount += 1;
        var difference = currentEpochTime - firstScalarRampEpochTime!;
        xAxisUnits = 'Time';

        var x = eventX ?? currentEpochTime;

        data = [PlotPoint(x: x, y: difference, t: currentEpochTime)];
      }
    } else if (forChannel == GenPlots.scalarRandRamp.name) {
      var rand = Random();

      firstScalarRandRampEpochTime ??= currentEpochTime;
      var value = currentEpochTime - firstScalarRandRampEpochTime!;

      value = value + (rand.nextInt(50) - 25);

      xAxisUnits = 'Time';

      var x = eventX ?? currentEpochTime;

      data = [PlotPoint(x: x, y: value, t: currentEpochTime)];
    } else if (forChannel == GenPlots.parabola.name) {
      data = List.generate(
          501,
          (i) => PlotPoint(
              x: (i - 250.0).toDouble(),
              y: pow(i - 250, 2).toDouble(),
              t: currentEpochTime));
    } else if (forChannel == GenPlots.parabola64k.name) {
      data = List.generate(
          65535,
          (i) => PlotPoint(
              x: (i - 32767.0).toDouble(),
              y: pow(i - 32767, 2).toDouble(),
              t: currentEpochTime));
    } else if (forChannel == GenPlots.sine.name) {
      data = List.generate(
          501,
          (i) => PlotPoint(
              x: (i - 250.0).toDouble(),
              y: sin((i - 250) / 500 * 6.28).toDouble(),
              t: currentEpochTime));
    } else if (forChannel == GenPlots.sine64k.name) {
      data = List.generate(
          65535,
          (i) => PlotPoint(
              x: (i - 32767.0).toDouble(),
              y: ((sin((i - 32767) / 65535 * 6.28) + 1) / 2 * 1073676289)
                  .toDouble(),
              t: currentEpochTime));
    } else if (forChannel == GenPlots.normal.name) {
      data = List.generate(
          500,
          (i) => PlotPoint(
              x: i.toDouble(),
              y: (pow(500, 2) / 4) *
                  pow(e, -(pow(i - 250, 2) / (2 * pow(50, 2)))).toDouble() /
                  (50 * sqrt(2 * pi)),
              t: currentEpochTime));
    }
    return (xAxisUnits, data);
  }
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

enum GenPlots {
  constant("PLOT TEST CONSTANT"),
  randConst("PLOT TEST RAND CONSTANT"),
  ramp("PLOT TEST RAMP"),
  randRamp("PLOT TEST RAND RAMP"),
  scalarRamp("PLOT TEST SCALAR RAMP"),
  slowScalarRamp("PLOT TEST SLOW SCALAR RAMP", minUpdateDelay: 50000),
  scalarRandRamp("PLOT TEST SCALAR RAND RAMP"),
  parabola("PLOT TEST PARABOLA"),
  parabola64k("PLOT TEST PARABOLA 64K"),
  sine("PLOT TEST SINE"),
  sine64k("PLOT TEST SINE 64K"),
  normal("PLOT TEST NORMAL");

  const GenPlots(this.name, {this.minUpdateDelay});
  final String name;
  final int? minUpdateDelay;
}

// Event of '10' is used for gen plots with reset of 10s acquisitions for scalar plots.
const int plotEvent = 16;

bool channelHasError(PlotChannelData chData) {
  return chData.status < 0;
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
