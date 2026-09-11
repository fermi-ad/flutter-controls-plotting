import 'package:flutter/material.dart';
import 'package:flutter_gql_acsys/flutter_gql_acsys.dart';

class PlotChannelTitle extends StatelessWidget {
  const PlotChannelTitle({
    super.key,
    required this.channelData,
    required this.chColor,
  });

  final PlotChannelData channelData;
  final Color chColor;

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(color: chColor, fontSize: 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(channelData.name, style: textStyle),
          Text(" (${channelData.units})", style: textStyle),
          channelData.rate.isEmpty
              ? Container()
              : Text(" - ${channelData.rate}", style: textStyle),
        ],
      ),
    );
  }
}
