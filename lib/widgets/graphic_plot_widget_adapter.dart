part of plotadapter;

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget, super.plotReply});

  @override
  Widget buildPlot() {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            _buildAxisTitles(constraints: constraints, child: _buildChart()));
  }

  Widget _buildAxisTitles(
      {required BoxConstraints constraints, required Widget child}) {
    final onTop = constraints.maxWidth < 600;

    List<Widget> children = <Widget>[];
    if (plotReply != null) {
      for (final channel in plotReply!.data) {
        final label = Text("${channel.name} (${channel.units})",
            style: TextStyle(color: lineColorForChannel(channel.name)));
        children
            .add(onTop ? label : RotatedBox(quarterTurns: -1, child: label));
      }
    }

    children.add(Expanded(child: child));
    return onTop ? Column(children: children) : Row(children: children);
  }

  Widget _buildChart() => Chart(
        data: _data,
        variables: {
          'Index': Variable(
              accessor: (Map datum) => datum['Index'] as double,
              scale: LinearScale(title: "Index")),
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
            color: (widget.plotChannels.isEmpty ||
                    widget.plotChannels.length == 1)
                ? ColorEncode(value: _channelColorList.first)
                : ColorEncode(variable: "Channel", values: _channelColorList),
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
          followPointer: [true, true],
          align: Alignment.topLeft,
          variables: ['Channel', 'Value'],
        ),
        crosshair: CrosshairGuide(followPointer: [false, true]),
      );

  List<Map<String, dynamic>> get _data {
    List<Map<String, dynamic>> data = [];

    if (plotReply != null && plotReply!.data.isNotEmpty) {
      for (final channel in plotReply!.data) {
        for (final point in channel.points) {
          var deviceValue = point.value;
          if (deviceValue is DevScalarArray) {
            // Handle DevScalarArray type
            for (int i = 0; i < deviceValue.value.length; i++) {
              data.add({
                "Index": i,
                "Value": deviceValue.value[i],
                "Channel": channel.name
              });
            }
          }
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
          .map((String channelName) => lineColorForChannel(channelName))
          .toList();
}
