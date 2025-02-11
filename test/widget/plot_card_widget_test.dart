import 'package:flutter/material.dart';
import 'package:flutter_controls_core/flutter_controls_core.dart';
import 'package:flutter_controls_plotting/service/fake_acsys_service.dart';
import 'package:flutter_controls_plotting/service/plot_daq_service.dart';
import 'package:flutter_controls_plotting/widgets/plot_card_widget.dart';
import 'package:flutter_controls_plotting/widgets/plot_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("PlotCardWidget widget tests", () {
    testWidgets("No title, display plot with no title on card",
        (WidgetTester tester) async {
      // Given nothing
      // When I build the PlotCard with no title parameter
      await tester.pumpWidget(_buildPlotCard(PlotCardWidget(
          plot: PlotWidget(
              plotChannels: const {}, daqService: StandardPlotDAQ()))));

      // Then the title is displayed inside the card
      expect(
          find.descendant(
              of: find.byType(Card),
              matching: find.descendant(
                  of: find.byType(Column),
                  matching: find.text("Empty Plot"),
                  matchRoot: true),
              matchRoot: true),
          findsNothing);
    });

    testWidgets("Provide title, title is displayed with plot",
        (WidgetTester tester) async {
      // Given a PlotCard titled with "Empty Plot"
      const title = "Empty Plot";

      // When I build the PlotCard
      await tester.pumpWidget(_buildPlotCard(PlotCardWidget(
          title: title,
          plot: PlotWidget(
              plotChannels: const {}, daqService: StandardPlotDAQ()))));

      // Then the title is displayed inside the card
      expect(
          find.ancestor(
              of: find.text(title),
              matching: find.byType(PlotCardWidget).first),
          findsOneWidget);
    });
  });
}

Widget _buildPlotCard(PlotCardWidget card) => MaterialApp(
    home: Scaffold(
        body: ACSysProvider(service: FakeACSysService(), child: card)));
