# Flutter Controls Plotting

Standard plotting widgets for Controls Flutter applications. Available plotting widgets:

- [Line chart](#line-chart)
- [Bar chart](#bar-chart)

## Line chart

TODO

## Bar chart

`BarChartWidget` acquires the latest scalar reading for each configured device.
A `BarChartController` can also add, replace, or remove client-managed segments
such as setpoints, limits, or composition values.

The public bar-chart API is renderer-neutral: clients use `BarChartModel`,
`BarSegment`, `BarChartStyle`, and `BarChartController`; they do not supply
`fl_chart` types. `BarChartAdapter` is the renderer boundary and the current
`FlChartBarAdapter` is an internal implementation detail. This keeps the data
contract, acquisition, and controller state reusable if the renderer changes.

### Grouped bars (default)

`BarChartLayout.grouped` preserves the original behavior. Each segment becomes
an independent side-by-side rod within the device's category.

```dart
final controller = BarChartController(deviceNames: ['MAGNET:A']);

controller.setSegment(
  device: 'MAGNET:A',
  key: 'reading',
  label: 'Reading',
  value: 12.5,
);
controller.setSegment(
  device: 'MAGNET:A',
  key: 'setpoint',
  label: 'Setpoint',
  value: 15,
);
```

### Stacked bars

Use `BarChartLayout.stacked` when a device's segments are components of one
bar. Each device may have a different number of segments. The order in which
segments are supplied is their bottom-to-top stack order.

```dart
final controller = BarChartController(
  deviceNames: ['SOURCE:A'],
  style: const BarChartStyle(layout: BarChartLayout.stacked),
);

// Additive segments contribute from the previous segment's end.
controller.setSegment(
  device: 'SOURCE:A',
  key: 'beam',
  label: 'Beam',
  value: 2.5,
);

// Explicit ranges are supported when the client owns the cumulative bounds.
controller.setRangeSegment(
  device: 'SOURCE:A',
  key: 'loss',
  label: 'Loss',
  start: 2.5,
  end: 3.0,
);
```

In stacked layout, positive and negative additive segments start independently
at zero: positive contributions accumulate upward and negative contributions
accumulate downward. Explicit ranges must remain on one side of zero and start
at the preceding segment's resolved end on that same signed side. Gaps,
overlaps, ranges crossing zero, ranges reversing toward zero, and non-finite
values throw `ArgumentError`; the controller retains its previous model state
when that happens. A small floating-point tolerance is applied when checking
contiguous explicit bounds.

### Axis presentation and limits

Configure axis divisions, Y labels, and device-label rotation through
`BarChartStyle` without exposing renderer types:

```dart
final style = BarChartStyle(
  minY: -1,
  maxY: 1,
  yAxisDivisions: 4,
  xAxisLabelRotation: 45,
  yAxisLabelFormatter: (value) => '${value.toStringAsFixed(2)} A',
);
```

`yAxisDivisions` is the number of equal intervals across the displayed Y range;
`null` preserves automatic renderer ticks. When no formatter is supplied, the
adapter derives enough decimal precision from the tick interval to distinguish
fractional values. Fixed Y limits clip the rendered rod geometry to the visible
range, while touch tooltips retain the original raw values and stacked ranges.
`xAxisLabelRotation` is expressed in degrees and is mapped to fl_chart's native
axis-title rotation.

Grouped layout remains the default for source compatibility. Existing calls to
`setSegment` remain additive values and therefore continue to render as
independent rods unless the style opts into stacked layout.

## Bar-chart feature coverage

### Exposed through the neutral API

- Categorical device groups and stable device ordering.
- Grouped rods and contiguous stacked rods.
- Additive contributions and explicit segment intervals.
- Per-device units and error state.
- Automatic or fixed Y-axis bounds with clipped render geometry and raw-value
  tooltips.
- Configurable Y-axis division count, precision-aware or custom Y labels, and
  degree-based X-label rotation.
- Segment width, segment/group spacing, corner radius, and colors.
- Axis-title visibility, device labels, error indicators, and touch tooltips.

### Fixed renderer policy

The fl_chart adapter uses space-around category alignment, fixed axis-title
layout and typography (except division count, Y label formatting, and rotation),
fixed tooltip styling, and a 10% auto-scale padding policy. These choices are
intentionally not public configuration yet.

### Not exposed

The bar abstraction does not currently expose fl_chart gradients, rod borders,
background rods, error indicators, grid/border styling, annotations or extra
lines, touch callbacks or programmatic highlights, group alignment, or
animation. No fl_chart configuration classes are part of the package's public
bar-chart API.

## Architecture assessment

The bar chart has a clean data-to-renderer boundary: `BarChartWidget` owns
stream lifecycle, `BarChartController` and `BarChartReducer` own neutral state,
and `BarChartAdapter` renders a `BarChartModel`. Unlike `PlotWidget`, which can
select among several renderer adapters, the bar widget currently constructs the
fl_chart adapter directly. Replacing the bar renderer would therefore require a
small widget-level selection or injection change, but would not require
changing the bar data contract.

## Testing

Run the focused bar-chart tests with:

```sh
flutter test test/widget/bar_chart_data_test.dart \
  test/widget/fl_chart_bar_adapter_test.dart \
  test/widget/bar_chart_widget_test.dart
```
