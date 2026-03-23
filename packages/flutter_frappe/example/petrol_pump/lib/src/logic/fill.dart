import 'package:frappe/frappe.dart';

import '../logic/accumulate.dart';
import '../model.dart';

/// Snapshots the per-liter price at the moment a fill begins.
///
/// When [startStream] fires with a fuel type, the corresponding price
/// state is sampled and held constant for the duration of that fill.
ValueState<double> _capturePrice(
    EventStream<Fuel> startStream,
    ValueState<double> price1State,
    ValueState<double> price2State,
    ValueState<double> price3State) {
  // When a fuel starts, snapshot the corresponding price.
  final price1Stream = startStream
      .snapshot<double, double?>(
          price1State,
          (startFuel, price) =>
              startFuel == Fuel.one ? price : null)
      .mapWhereNotNull();

  final price2Stream = startStream
      .snapshot<double, double?>(
          price2State,
          (startFuel, price) =>
              startFuel == Fuel.two ? price : null)
      .mapWhereNotNull();

  final price3Stream = startStream
      .snapshot<double, double?>(
          price3State,
          (startFuel, price) =>
              startFuel == Fuel.three ? price : null)
      .mapWhereNotNull();

  return price1Stream.orElses([price2Stream, price3Stream]).toState(0);
}

/// Computes fill data: price, dollars delivered, liters delivered.
class Fill {
  /// The per-liter price captured at the start of the current fill.
  final ValueState<double> priceState;

  /// The total dollar amount delivered so far (liters * price).
  final ValueState<double> dollarsDeliveredState;

  /// The total liters delivered so far (accumulated pulses * calibration).
  final ValueState<double> litersDeliveredState;

  factory Fill({
    required EventStream<Unit> clearAccumulatorStream,
    required EventStream<int> fuelsPulsesStream,
    required ValueState<double> calibrationState,
    required ValueState<double> price1State,
    required ValueState<double> price2State,
    required ValueState<double> price3State,
    required EventStream<Fuel> startStream,
  }) {
    // Step 1: Lock in the per-liter price at the moment filling starts.
    final priceState =
        _capturePrice(startStream, price1State, price2State, price3State);

    // Step 2: Accumulate raw fuel pulses into calibrated liters.
    final litersDeliveredState =
        accumulate(clearAccumulatorStream, fuelsPulsesStream, calibrationState);

    // Step 3: Derive the dollar total from liters and captured price.
    final dollarsDeliveredState = litersDeliveredState.combine(
        priceState, (liters, price) => liters * price);

    return Fill._(
      priceState: priceState,
      dollarsDeliveredState: dollarsDeliveredState,
      litersDeliveredState: litersDeliveredState,
    );
  }

  /// References all reactive fields via [collector], keeping them alive
  /// until the collector is disposed. Returns `this` for chaining.
  Fill hold(FrappeReferenceCollector collector) {
    collector
      ..add(priceState)
      ..add(dollarsDeliveredState)
      ..add(litersDeliveredState);
    return this;
  }

  Fill._({
    required this.priceState,
    required this.dollarsDeliveredState,
    required this.litersDeliveredState,
  });
}
