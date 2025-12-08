part of plotadapter;

class FermiPlotWidgetAdapter extends PlotWidgetAdapter {
  FermiPlotWidgetAdapter({required super.plotWidget, super.plotReply});

  @override
  Widget buildPlot() {
    // TODO: Implement Fermi plot rendering
    return Container(
      color: Colors.grey[200],
      child: const Center(child: Text('Fermi Plot Implementation Coming Soon')),
    );
  }
}
