The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## 1.2.0 2026-10-13

### Added

- Add opt-in stacked bar charts through `BarChartLayout.stacked`, with positive and negative contributions accumulating independently from zero.
- Add renderer-neutral explicit segment ranges through `BarSegment.range` and `BarChartController.setRangeSegment`.
- Validate stacked segments for finite values, contiguous ranges, and direction away from zero. Invalid value updates preserve the previous chart state.
- Add configurable Y-axis division counts, custom Y-axis label formatting, and X-axis device-label rotation through `BarChartStyle`.
- Add regression tests for stacked data, range validation, clipping, axis presentation, and tooltip behavior.

### Changed

- Render stacked segments as one colored bar per device, with automatic Y bounds based on resolved segment intervals and tooltips showing segment ranges and device units.
- Use precision-aware default Y-axis labels for configured fractional tick intervals.
- Align horizontal grid lines with configured Y-axis divisions and hide vertical grid lines.
- Expand bar-chart documentation with usage examples, API behavior, feature coverage, renderer limitations, and testing instructions.
- Update the dependency lockfile to resolve `flutter_controls_core` 1.4.0.
- Preserve grouped bars as the default layout for existing callers.

### Fixed

- Preserve the configured bar-chart style in the initial empty model.
- Clip grouped and stacked bar geometry to the visible Y-axis limits while retaining original model values for tooltip details.
- Keep rotated device labels anchored to their categories and reserve space to reduce label clipping.
- Keep bar-chart tooltips within plot bounds using automatic placement.
- Validate remaining stacked segments before publishing removals; reject invalid removals without changing chart state or notifying listeners.
- Document fixed explicit-range bounds and atomic rejection of streamed updates that break stack contiguity, with regression coverage for both signed sides and multi-device operations.

## 1.1.0 2026-09-15

### Added

- `BarChartWidget` has been added to the library.

### Changed

- Change fermi dependencies to use tag versioning.
- Add `flutter_gql_acsys` dependency.
- Much of the `flutter_controls_core` usage has been moved to `flutter_gql_acsys`. Those changes have been propagated here.
