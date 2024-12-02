part of plotadapter;

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot() {
    return Chart(
      data: _data,
      variables: {
        'Index': Variable(
            accessor: (Map datum) => datum['Index'] as double,
            scale: LinearScale()),
        'Value': Variable(
            accessor: (Map datum) => datum['Value'] as double,
            scale: LinearScale()),
        'Channel': Variable(
          accessor: (Map datum) => datum['Channel'] as String,
        ),
      },
      marks: [
        LineMark(
          position: Varset('Index') * Varset('Value') / Varset('Channel'),
          color:
              (widget.plotChannels.isEmpty || widget.plotChannels.length == 1)
                  ? ColorEncode(value: _channelColorList.first)
                  : ColorEncode(variable: "Channel", values: _channelColorList),
          shape: ShapeEncode(value: BasicLineShape()),
          selected: {
            'touchMove': {1}
          },
        ),
      ],
      coord: RectCoord(),
      axes: [
        Defaults.horizontalAxis,
        Defaults.verticalAxis,
      ],
      selections: {
        'touchMove': PointSelection(
          on: {
            GestureType.scaleUpdate,
            GestureType.tapDown,
            GestureType.longPressMoveUpdate
          },
          dim: Dim.x,
        )
      },
      tooltip: TooltipGuide(
        followPointer: [false, true],
        align: Alignment.topLeft,
        offset: const Offset(-20, -20),
      ),
      crosshair: CrosshairGuide(followPointer: [false, true]),
    );
  }

  List<Map<String, dynamic>> get _data {
    List<Map<String, dynamic>> data = [];

    if (plotReply != null && plotReply!.data.isNotEmpty) {
      for (final channel in plotReply!.data) {
        for (final point in channel.points) {
          data.add(
              {"Index": point.x, "Value": point.y, "Channel": channel.name});
        }
      }
    } else {
      data = [
        {'Index': 0.0, 'Value': 0.0, "Channel": "None"},
        {'Index': 1.0, 'Value': 1.0, "Channel": "None"}
      ];
    }

    return data;
  }

  List<Color> get _channelColorList => widget.plotChannels.isEmpty
      ? [Colors.red]
      : widget.plotChannels.keys
          .map((String channelName) => _lineColorForChannel(channelName))
          .toList();
}
