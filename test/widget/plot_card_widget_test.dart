import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_card_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotCardWidget widget tests", () {
    testWidgets("Provide title, title is displayed with plot",
        (WidgetTester tester) async {
      // Given a PlotCard titled with "Empty Plot"
      const title = "Empty Plot";

      // When I build the PlotCard
      tester.pumpWidget(Scaffold(
          body: ACSysProvider(
              service: FakeACSysService(),
              child: const PlotCardWidget(
                  title: title,
                  child: PlotWidget(
                      plotChannels: {}, daqService: StandardPlotDAQ())))));

      // Then the title is displayed inside the card
      expect(
          find.ancestor(
              of: find.text(title),
              matching: find.byType(PlotCardWidget).first),
          findsOneWidget);
    });
  });
}
