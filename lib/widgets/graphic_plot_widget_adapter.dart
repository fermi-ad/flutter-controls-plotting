part of plotadapter;

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot() {
    return Chart(
      data: _data,
      variables: {
        'Index': Variable(
          accessor: (Map datum) => datum['Index'] as num,
        ),
        'Value': Variable(
          accessor: (Map datum) => datum['Value'] as num,
        ),
        'Channel': Variable(
          accessor: (Map datum) => datum['Channel'] as String,
        ),
      },
      marks: _lineMarks,
      coord: RectCoord(color: const Color(0xffdddddd)),
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
              {"Channel": channel.name, "Index": point.x, "Value": point.y});
        }
      }
    } else {
      data = [
        {'Index': 0, 'Value': 0, "Channel": "None"},
        {'Index': 1, 'Value': 1, "Channel": "None"}
      ];
    }

    return data;
  }

  List<LineMark> get _lineMarks => [
        LineMark(
          color: ColorEncode(value: Colors.blue),
          shape: ShapeEncode(value: BasicLineShape()),
          selected: {
            'touchMove': {1}
          },
        ),
      ];
}
