import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/widgets/plot_card_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';

class PlotDemoWidget extends StatelessWidget {
  const PlotDemoWidget({super.key});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
          builder: (context, constraints) => GridView.count(
                  crossAxisCount: constraints.maxWidth > 1000 ? 2 : 1,
                  children: [
                    _buildEmptyPlot(),
                    _buildWaveformPlot(),
                    _buildMultipleWaveformPlot()
                  ])));

  Widget _buildEmptyPlot() => PlotCardWidget(
      title: "Empty Plot",
      plot: PlotWidget(
        implementation: _implementation,
      ));

  Widget _buildWaveformPlot() => PlotCardWidget(
      title: "Single Waveform Plot",
      plot: PlotWidget(
          implementation: _implementation,
          plotChannels: {"PLOT TEST PARABOLA": ChannelSetting()}));

  Widget _buildMultipleWaveformPlot() => PlotCardWidget(
      title: "Multiple Waveforms Plot",
      plot: PlotWidget(implementation: _implementation, plotChannels: {
        "PLOT TEST RAND RAMP": ChannelSetting(),
        "PLOT TEST NORMAL": ChannelSetting()
      }));

  final _implementation = PlotImplementation.graphic;
}
