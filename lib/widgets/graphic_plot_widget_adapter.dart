part of plotadapter;

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot(
      {required PlotReply? plotReply, required List<String> yLimits}) {
    List<List<PlotPoint>> filteredChannelPoints;

    if (plotReply != null) {
      // _findLimits will filter the data according to the minY, maxY.
      filteredChannelPoints =
          _findLimits(plotChannels: plotReply.data, yLimits: yLimits);
    } else {
      // Defaults
      minX = 0.0;
      minY = 0.0;
      maxX = 1.0;
      maxY = 1.0;
    }

    return Chart(
      data: const [
        {'index': 0, 'v': 0},
        {
          'index': 1,
          'v': 1
        }, /*
          {'index': 2, 'v': 2},
          {'index': 3, 'v': 3},
          {'index': 4, 'v': 4},*/
      ],
      variables: {
        'index': Variable(
          accessor: (Map map) => map['index'] as num,
        ),
        'v': Variable(
          accessor: (Map map) => map['v'] as num,
        ),
      },
      marks: [
        LineMark(
          shape: ShapeEncode(value: BasicLineShape(dash: [5, 2])),
          selected: {
            'touchMove': {1}
          },
        )
      ],
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
}
