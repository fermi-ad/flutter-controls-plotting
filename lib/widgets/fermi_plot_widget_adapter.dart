part of plotadapter;

class FermiPlotWidgetAdapter extends PlotWidgetAdapter {
  FermiPlotWidgetAdapter({required super.widget});

  @override
  Widget buildPlot(
          {required PlotReply? plotReply, required List<String> yLimits}) =>
      Container();
}
