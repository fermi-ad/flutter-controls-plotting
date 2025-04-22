// Defines a default set of colors for plots. It is possible to pass in any color as well.
import 'package:flutter/material.dart';

class ChannelSetting {
  Color? lineColor;
  PlotMarker plotMarker;

  ChannelSetting({this.lineColor, this.plotMarker = PlotMarker.line});

  // Clone functionality.
  static ChannelSetting from(ChannelSetting setting) {
    var newChannelSetting = ChannelSetting(
        lineColor: setting.lineColor, plotMarker: setting.plotMarker);
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
}
