import 'package:frappe/frappe.dart';

/// Accumulates fuel pulses, resettable via [clearAccumulatorStream],
/// and multiplied by [calibrationState].
ValueState<double> accumulate(
  EventStream<Unit> clearAccumulatorStream,
  EventStream<int> deltaStream,
  ValueState<double> calibrationState,
) {
  final totalStateRef = ValueStateLink<double>();

  totalStateRef.connect(clearAccumulatorStream
      .mapTo(0.0)
      .orElse(deltaStream.snapshot(
          totalStateRef.state, (delta, total) => total + delta))
      .toState(0.0));

  return totalStateRef.state.combine(
    calibrationState,
    (total, calibration) => total * calibration,
  );
}
