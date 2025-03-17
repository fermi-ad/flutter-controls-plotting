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

  double? lastScalarRampEpochTime;
  double? lastScalarRandRampEpochTime;

  int? eventAcquisitionCount;
  int? eventAcquisitionLimit;

  // Test variables
  int scalarRampCount = 0;
  int scalarRampEventDuration = 10;
  int? scalarRampCountLimit;

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
    if (updateDelay == 0) {
      // No refresh cycle, attempt to combine gen plots with api results
      var generatePlot = _generatePlot(forChannels: forChannels, args: args);

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

        var apiResponse = apiStream.first;
        apiResponse.then((PlotReply value) {
          generatePlot.data.addAll(value.data);
        });

        yield generatePlot;
      }

      yield generatePlot;
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

      var requestTime = _getCurrentEpochTime();

      while (validLoop) {
        await Future.delayed(Duration(microseconds: updateDelay));
        double? eventX;

        if (triggerEvent != null && eventAcquisitionCount != null) {
          eventX = (scalarRampEventDuration * eventAcquisitionCount!) /
              (eventAcquisitionLimit!);

          if (eventAcquisitionCount == eventAcquisitionLimit) {
            eventAcquisitionCount = 0;
          } else {
            eventAcquisitionCount = eventAcquisitionCount! + 1;
          }
        }

        var plot = _generatePlot(
            forChannels: forChannels,
            requestTime: requestTime,
            args: args,
            markChannelNameErrors: true,
            eventX: eventX);

        validLoop = false;
        for (var channel in plot.data) {
          if (channel.points.isNotEmpty) {
            // Atleast one channel has points.
            validLoop = true;
          }
        }

        yield plot;

        nAcquisitionsInLoop += 1;
        if (nAcquisitions != null && nAcquisitionsInLoop == nAcquisitions) {
          validLoop = false;
        }
      }
    }
  }

  PlotReply _generatePlot(
      {required Set<String> forChannels,
      required _PlotArgs args,
      required double requestTime,
      bool markChannelNameErrors = false,
      double? eventX}) {
    List<PlotChannelData> internalDaqData = [];
    var xAxisUnits = 'Index';

    var currentEpochTime = _getCurrentEpochTime();

    for (var forChannel in forChannels) {
      List<PlotPoint>? data;
      if (forChannel == GenPlots.constant.name) {
        data = List.generate(500,
            (i) => PlotPoint(x: i.toDouble(), y: 5.0, t: currentEpochTime));
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
            (i) => PlotPoint(
                x: i.toDouble(), y: i.toDouble(), t: currentEpochTime));
      } else if (forChannel == GenPlots.randRamp.name) {
        var rand = Random();
        data = List.generate(
            500,
            (i) => PlotPoint(
                x: i.toDouble(),
                y: i.toDouble() + (rand.nextInt(50) - 25),
                t: currentEpochTime));
      } else if (forChannel == GenPlots.scalarRamp.name) {
        lastScalarRampEpochTime ??= currentEpochTime;
        if (scalarRampCountLimit != null &&
            scalarRampCount >= scalarRampCountLimit!) {
          data = [];
        } else {
          scalarRampCount += 1;
          var difference = currentEpochTime - lastScalarRampEpochTime!;
          xAxisUnits = 'Time';

          var x = eventX ?? currentEpochTime;

          data = [PlotPoint(x: x, y: difference, t: currentEpochTime)];
        }
      } else if (forChannel == GenPlots.scalarRandRamp.name) {
        var rand = Random();
        var currentEpochTime = _getCurrentEpochTime();
        lastScalarRandRampEpochTime ??= currentEpochTime;

        var value = currentEpochTime - lastScalarRandRampEpochTime!;
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

      if (data != null) {
        internalDaqData
            .add(PlotChannelData(name: forChannel, units: "V", points: data));
        args.xMax = max(args.xMax, data.length - 1);
        args.windowSize = max(args.windowSize, data.length);
      } else if (markChannelNameErrors) {
        internalDaqData
            .add(PlotChannelData(name: forChannel, units: "", status: -1));
      }
    }

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
}

double _getCurrentEpochTime() {
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
  scalarRandRamp("PLOT TEST SCALAR RAND RAMP"),
  parabola("PLOT TEST PARABOLA"),
  parabola64k("PLOT TEST PARABOLA 64K"),
  sine("PLOT TEST SINE"),
  normal("PLOT TEST NORMAL");

  const GenPlots(this.name);
  final String name;
}

// Event of '10' is used for gen plots with reset of 10s acquisitions for scalar plots.
const int plotEvent = 16;

bool channelHasError(PlotChannelData chData) {
  return chData.status < 0;
}

bool channelHasErrorOrNoPoints(PlotChannelData chData) {
  return channelHasError(chData) || chData.points.isEmpty;
}
