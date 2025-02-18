import 'package:flutter/material.dart';
import 'package:flutter_controls_plotting/entities/channel_setting.dart';
import 'package:flutter_controls_plotting/entities/plot_data.dart';
import 'package:flutter_controls_plotting/entities/scalar_data_options.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_card_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';

class PlotDemoWidget extends StatefulWidget {
  const PlotDemoWidget({super.key});

  @override
  State<StatefulWidget> createState() => PlotDemoState();
}

class PlotDemoState extends State<PlotDemoWidget> {
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: DropdownMenu<String>(
              initialSelection: "Fl_Charts",
              label: const Text("Plot Implementation"),
              onSelected: _handleImplementationSelected,
              dropdownMenuEntries: const [
                DropdownMenuEntry<String>(
                    value: "Fl_Charts", label: "Fl_Charts"),
                DropdownMenuEntry<String>(value: "Graphic", label: "Graphic"),
                DropdownMenuEntry<String>(value: "Fermi", label: "Custom")
              ],
            )),
        Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                        crossAxisCount: constraints.maxWidth > 1000 ? 2 : 1,
                        children: [
                          _buildEmptyPlot(),
                          _buildWaveformPlot(),
                          _buildMultipleWaveformPlot(),
                          _buildTimedScalarWaveformPlot()
                        ])))
      ]));

  Widget _buildEmptyPlot() => PlotCardWidget(
      title: "Empty Plot",
      plot: PlotWidget(
        implementation: _implementation,
        plotData: PlotData(),
        daqService: StandardPlotDAQ(),
      ));

  Widget _buildWaveformPlot() => PlotCardWidget(
      title: "Single Waveform Plot",
      plot: PlotWidget(
          implementation: _implementation,
          plotData: PlotData(),
          daqService: StandardPlotDAQ(),
          plotChannels: {"PLOT TEST PARABOLA": ChannelSetting()}));

  Widget _buildMultipleWaveformPlot() => PlotCardWidget(
      title: "Multiple Waveforms Plot",
      plot: PlotWidget(
          implementation: _implementation,
          plotData: PlotData(),
          daqService: StandardPlotDAQ(),
          plotChannels: {
            "PLOT TEST RAND RAMP": ChannelSetting(),
            "PLOT TEST NORMAL": ChannelSetting()
          }));

  Widget _buildTimedScalarWaveformPlot() => PlotCardWidget(
      title: "Timed Scalar Plot",
      plot: PlotWidget(
          implementation: _implementation,
          plotData: PlotData(),
          daqService: StandardPlotDAQ(),
          scalarDataOptions:
              ScalarDataOptions(isOneShot: false, timeDelta: null),
          updateDelay: 500,
          plotChannels: {
            "PLOT TEST SCALAR RAND RAMP": ChannelSetting(),
          }));

  void _handleImplementationSelected(String? implementation) {
    if (implementation == null) {
      return;
    } else if (implementation == "Fl_Charts") {
      setState(() => _implementation = PlotImplementation.flCharts);
    } else if (implementation == "Graphic") {
      setState(() => _implementation = PlotImplementation.graphic);
    } else if (implementation == "Fermi") {
      assert(false);
    }
  }

  PlotImplementation _implementation = PlotImplementation.flCharts;
}
