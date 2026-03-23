import 'package:frappe/frappe.dart';

/// Accumulates fuel pulses, resettable via [clearAccumulatorStream],
/// and multiplied by [calibrationState].
///
/// - [clearAccumulatorStream] resets the running total to zero.
/// - [deltaStream] provides raw pulse increments to accumulate.
/// - [calibrationState] is a multiplier converting raw pulses to liters.
ValueState<double> accumulate(
  EventStream<Unit> clearAccumulatorStream,
  EventStream<int> deltaStream,
  ValueState<double> calibrationState,
) {
  // loop breaks the cyclic dependency: the running total references itself
  // (previous value + delta). On clear, reset to 0; on delta, add to
  // the current total. orElse gives clear priority within the same transaction.
  // loop breaks the cyclic dependency: the running total references itself
  // (previous value + delta). On clear, reset to 0; on delta, add to
  // the current total. orElse gives clear priority within the same transaction.
  final totalState = ValueState.loop<double>((self, connect) {
    connect(clearAccumulatorStream
        .mapTo(0.0)
        .orElse(deltaStream.snapshot(self, (delta, total) => total + delta))
        .toState(0.0));
  });

  // Apply calibration factor to convert raw pulse count to liters.
  return totalState.combine(
    calibrationState,
    (total, calibration) => total * calibration,
  );
}
