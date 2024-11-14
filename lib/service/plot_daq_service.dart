import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';

abstract class PlotDAQService {
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required String forChannel});
}

class StandardPlotDAQ implements PlotDAQService {
  @override
  Stream<PlotReply> retrievePlot(BuildContext context,
      {required String forChannel}) {
    switch (forChannel) {
      case "PLOT TEST CONSTANT":
        final data =
            List.generate(500, (i) => PlotPoint(x: i.toDouble(), y: 5.0));
        return Stream<PlotReply>.value(PlotReply(
            plotId: "Internal",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: data.length - 1,
            windowSize: data.length,
            data: [
              PlotChannelData(name: forChannel, units: "V", points: data)
            ]));

      case "PLOT TEST RAMP":
        final data = List.generate(
            500, (i) => PlotPoint(x: i.toDouble(), y: i.toDouble()));
        return Stream<PlotReply>.value(PlotReply(
            plotId: "Internal",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: data.length - 1,
            windowSize: data.length,
            data: [
              PlotChannelData(name: forChannel, units: "V", points: data)
            ]));

      case "PLOT TEST PARABOLA":
        final data = List.generate(
            501,
            (i) => PlotPoint(
                x: (i - 250.0).toDouble(), y: pow(i - 250, 2).toDouble()));
        return Stream<PlotReply>.value(PlotReply(
            plotId: "Internal",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: data.length - 1,
            windowSize: data.length,
            data: [
              PlotChannelData(name: forChannel, units: "V", points: data)
            ]));

      case "PLOT TEST PARABOLA 64K":
        final data = List.generate(
            65535,
            (i) => PlotPoint(
                x: (i - 32767.0).toDouble(), y: pow(i - 32767, 2).toDouble()));
        return Stream<PlotReply>.value(PlotReply(
            plotId: "Internal",
            xAxisUnits: "Index",
            xAxisMin: 0,
            xAxisMax: data.length - 1,
            windowSize: data.length,
            data: [
              PlotChannelData(name: forChannel, units: "V", points: data)
            ]));

      case "PLOT TEST SINE":
        return Stream<PlotReply>.fromFuture(
            Future.delayed(const Duration(seconds: 1), () {
          final data = List.generate(
              501,
              (i) => PlotPoint(
                  x: (i - 250.0).toDouble(),
                  y: sin((i - 250) / 500 * 6.28).toDouble()));
          return PlotReply(
              plotId: "Internal",
              xAxisUnits: "Index",
              xAxisMin: 0,
              xAxisMax: data.length - 1,
              windowSize: data.length,
              data: [
                PlotChannelData(name: forChannel, units: "V", points: data)
              ]);
        }));

      default:
        return ACSys.api(context)
            .startPlot([forChannel], xMin: 0, xMax: 499, windowSize: 500);
    }
  }
}
