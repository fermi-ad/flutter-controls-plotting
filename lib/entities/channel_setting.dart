// Defines a default set of colors for plots. It is possible to pass in any color as well.
import 'package:flutter/material.dart';

class ChannelSetting {
  // "Displayed limits" refer to the Y-axis range currently shown on the chart.
  // These can be presented in either log or linear scale, depending on the chart settings.

  // "Label limits" refer to the numeric values shown as Y-axis labels and tooltips.
  // These always represent values in linear scale, regardless of the display scale.

  // "Config limits" refer to the user-defined minY and maxY values.
  // When config limits are set, the displayed limits match these user-defined values.
  Color? lineColor;
  PlotMarker plotMarker;
  double? displayedMinY;
  double? displayedMaxY;
  double? labelMinY;
  double? labelMaxY;
  double? confMinY;
  double? confMaxY;
  bool isLogScale;

  ChannelSetting({
    this.lineColor,
    this.plotMarker = PlotMarker.line,
    this.displayedMinY,
    this.displayedMaxY,
    this.labelMinY,
    this.labelMaxY,
    this.confMinY,
    this.confMaxY,
    this.isLogScale = false,
  });

  // Clone functionality.
  static ChannelSetting from(ChannelSetting setting) {
    var newChannelSetting = ChannelSetting(
      lineColor: setting.lineColor,
      plotMarker: setting.plotMarker,
      displayedMinY: setting.displayedMinY,
      displayedMaxY: setting.displayedMaxY,
      labelMinY: setting.labelMinY,
      labelMaxY: setting.labelMaxY,
      confMinY: setting.confMinY,
      confMaxY: setting.confMaxY,
      isLogScale: setting.isLogScale,
    );
    return newChannelSetting;
  }
}

enum PlotColor {
  red("Red", Colors.red),
  green("Green", Colors.green),
  blue("Blue", Colors.blue),
  yellow("Yellow", Colors.yellow),
  brown("Brown", Colors.brown),
  gray("Gray", Colors.blueGrey),
  purple("Purple", Colors.purple),
  lime("Lime", Colors.lime),
  cyan("Cyan", Colors.cyan),
  orange("Orange", Colors.orange),
  invisible("Invisible", Colors.transparent);

  const PlotColor(this.name, this.color);
  final String name;
  final Color color;
}

enum PlotMarker {
  line("Line", 0),
  lineDots("Line Dot", 1),
  dot("Dots", 2),
  cirle("Circles", 3),
  cross("Cross", 4),
  square("Square", 5),
  oooooo("OOOOOO", 6),
  kkkkkk("KKKKKK", 7),
  vvvvvv("VVVVVV", 8),
  heart("Icon heart", 9),
  arrow("Icon arrow", 10),
  star("Icon star", 11),
  triangle("Icon Triangle", 12);

  const PlotMarker(this.name, this.markerIndex); // Ensure this line is correct
  final String name;
  final int markerIndex; // Ensure this line is correct

  static PlotMarker getPlotMarkerForIndex(int index) {
    return PlotMarker.values.firstWhere(
      (marker) => marker.markerIndex == index,
      orElse: () => PlotMarker.line,
    );
  }
}
