import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

abstract class PlotDAQService {
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required Set<String> forChannels});
}

class StandardPlotDAQ implements PlotDAQService {
  const StandardPlotDAQ();

  @override
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required Set<String> forChannels}) {
    List<String> apiChannels = [];
    List<PlotChannelData> internalDaqData = [];

    bool addSimlatedWait = false;
    var xMin = 0;
    var xMax = 499;
    var windowSize = 500;

    for (var forChannel in forChannels) {
      List<PlotPoint>? data;
      switch (forChannel) {
        case "PLOT TEST CONSTANT":
          data = List.generate(500, (i) => PlotPoint(x: i.toDouble(), y: 5.0));
          break;

        case "PLOT TEST RAMP":
          data = List.generate(
              500, (i) => PlotPoint(x: i.toDouble(), y: i.toDouble()));
          break;

        case "PLOT TEST RAND RAMP":
          var rand = Random();
          data = List.generate(
              500,
              (i) => PlotPoint(
                  x: i.toDouble(), y: i.toDouble() + (rand.nextInt(50) - 25)));
          break;

        case "PLOT TEST PARABOLA":
          data = List.generate(
              501,
              (i) => PlotPoint(
                  x: (i - 250.0).toDouble(), y: pow(i - 250, 2).toDouble()));
          break;

        case "PLOT TEST PARABOLA 64K":
          data = List.generate(
              65535,
              (i) => PlotPoint(
                  x: (i - 32767.0).toDouble(),
                  y: pow(i - 32767, 2).toDouble()));
          break;

        case "PLOT TEST SINE":
          addSimlatedWait = true;
          data = List.generate(
              501,
              (i) => PlotPoint(
                  x: (i - 250.0).toDouble(),
                  y: sin((i - 250) / 500 * 6.28).toDouble()));
          break;

        case "PLOT TEST NORMAL":
          data = List.generate(
              500,
              (i) => PlotPoint(
                  x: i.toDouble(),
                  y: (pow(500, 2) / 4) *
                      pow(e, -(pow(i - 250, 2) / (2 * pow(50, 2)))).toDouble() /
                      (50 * sqrt(2 * pi))));
          break;

        default:
          apiChannels.add(forChannel);
          break;
      }

      if (data != null) {
        internalDaqData
            .add(PlotChannelData(name: forChannel, units: "V", points: data));
        xMax = max(xMax, data.length - 1);
        windowSize = max(windowSize, data.length);
      }
    }

    if (apiChannels.isNotEmpty && internalDaqData.isEmpty) {
      // API only request
      return ACSys.api(context).startPlot(apiChannels,
          xMin: xMin, xMax: xMax, windowSize: windowSize);
    } else if (apiChannels.isNotEmpty) {
      // Internal and API request
      var apiStream = ACSys.api(context).startPlot(apiChannels,
          xMin: xMin, xMax: xMax, windowSize: windowSize);

      var apiResponse = apiStream.first;
      var modifiedResponse = apiResponse.then((PlotReply value) {
        value.data.addAll(internalDaqData);
        return value;
      });

      return Stream<PlotReply>.fromFuture(modifiedResponse);
    }
    // Internal only request.
    var generatedPlotReply = PlotReply(
        plotId: "Internal",
        xAxisUnits: "Index",
        xAxisMin: xMin + 0.0,
        xAxisMax: xMax + 0.0,
        windowSize: windowSize,
        data: internalDaqData);

    if (addSimlatedWait) {
      return Stream<PlotReply>.fromFuture(
          Future.delayed(const Duration(seconds: 1), () {
        return generatedPlotReply;
      }));
    }

    return Stream<PlotReply>.value(generatedPlotReply);
  }
}
