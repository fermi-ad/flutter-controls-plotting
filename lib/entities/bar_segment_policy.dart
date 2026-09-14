import 'package:flutter_controls_plotting/entities/bar_chart_model.dart';
import 'package:flutter_controls_plotting/entities/bar_chart_style.dart';
import 'package:flutter_controls_plotting/entities/bar_segment.dart';

/// Converts named measurements into ordered visual intervals.
abstract class BarSegmentPolicy {
  const BarSegmentPolicy();

  List<BarSegment> buildSegments({
    required String device,
    required List<BarValue> values,
    required BarChartStyle style,
  });
}

/// Default policy for a current value compared with a captured reference.
class ReferenceDeltaSegmentPolicy extends BarSegmentPolicy {
  const ReferenceDeltaSegmentPolicy();

  @override
  List<BarSegment> buildSegments({
    required String device,
    required List<BarValue> values,
    required BarChartStyle style,
  }) {
    final current = _value(values, 'current');
    if (current?.value == null) return const [];
    final reference = _value(values, 'reference')?.value;
    if (reference == null) {
      return [
        BarSegment(
          key: 'current',
          label: current!.label,
          fromY: 0,
          toY: current.value!,
          style: style.styleFor('current'),
        ),
      ];
    }

    if (current!.value == reference) {
      return [
        BarSegment(
          key: 'reference',
          label: 'Reference',
          fromY: 0,
          toY: reference,
          style: style.styleFor('reference'),
        ),
      ];
    }

    if (current.value! > reference) {
      return [
        BarSegment(
          key: 'reference',
          label: 'Reference',
          fromY: 0,
          toY: reference,
          style: style.styleFor('reference'),
        ),
        BarSegment(
          key: 'higher',
          label: 'Higher',
          fromY: reference,
          toY: current.value!,
          style: style.styleFor('higher'),
        ),
      ];
    }

    return [
      BarSegment(
        key: 'current',
        label: current.label,
        fromY: 0,
        toY: current.value!,
        style: style.styleFor('current'),
      ),
      BarSegment(
        key: 'lower',
        label: 'Lower',
        fromY: current.value!,
        toY: reference,
        style: style.styleFor('lower'),
      ),
    ];
  }

  BarValue? _value(List<BarValue> values, String key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}
