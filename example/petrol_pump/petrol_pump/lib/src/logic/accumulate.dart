import 'package:frappe/frappe.dart';

ValueState<double> accumulate(
  EventStream<Unit> clearAccumulatorStream,
  EventStream<int> deltaStream,
  ValueState<double> calibrationState,
) {
  final totalStateRef = ValueStateReference();

  totalStateRef.link(clearAccumulatorStream
      .mapTo(0)
      .orElse(deltaStream.snapshot(
          totalStateRef.state, (delta, total) => total + delta))
      .toState(0));

  return totalStateRef.state.combine(
    calibrationState,
    (total, calibration) => total * calibration,
  );
}
