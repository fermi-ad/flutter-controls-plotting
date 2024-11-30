part of plotadapter;

class GraphicPlotWidgetAdapter extends PlotWidgetAdapter {
  GraphicPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot() {
    return Chart(
      data: _data,
      variables: _variables,
      marks: _lineStyles,
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

  List<Map<String, double>> get _data {
    List<Map<String, double>> data = [];

    if (plotReply != null && plotReply!.data.isNotEmpty) {
      for (int i = 0; i != plotReply!.data.first.points.length - 1; i++) {
        Map<String, double> element = {'Index': i.toDouble()};
        for (int j = 0; j != plotReply!.data.length; j++) {
          element[plotReply!.data[j].name] = plotReply!.data[j].points[i].y;
        }
        data.add(element);
      }
    } else {
      data = [
        {'Index': 0, 'v': 0},
        {'Index': 1, 'v': 1}
      ];
    }

    return data;
  }

  Map<String, Variable<Map<dynamic, dynamic>, dynamic>> get _variables {
    Map<String, Variable<Map<dynamic, dynamic>, dynamic>> variables = {};
    variables['Index'] = Variable(
      accessor: (Map map) => map['Index'] as num,
    );

    if (plotReply != null) {
      for (final channel in plotReply!.data) {
        variables[channel.name] = Variable(
          accessor: (Map map) => map[channel.name] as num,
        );
      }
    } else {
      variables['v'] = Variable(
        accessor: (Map map) => map['v'] as num,
      );
    }

    return variables;
  }

  List<LineMark> get _lineStyles => widget.plotChannels.isEmpty
      ? [_lineMarkWithColor(Colors.blue)]
      : [
          _lineMarkWithColor(
              _nextColorForIndex(widget.plotChannels.keys.first)),
        ];

  LineMark _lineMarkWithColor(Color c) => LineMark(
        color: ColorEncode(value: c),
        shape: ShapeEncode(value: BasicLineShape()),
        selected: {
          'touchMove': {1}
        },
      );
}
