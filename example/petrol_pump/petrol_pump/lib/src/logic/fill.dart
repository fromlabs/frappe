import 'package:meta/meta.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';

import '../logic/accumulate.dart';
import '../model.dart';

ValueState<double> _capturePrice(
    EventStream<Fuel> startStream,
    ValueState<double> price1State,
    ValueState<double> price2State,
    ValueState<double> price3State) {
  final price1Stream = startStream
      .snapshot<double, double?>(price1State,
          (startFuel, price) => startFuel == Fuel.one ? price : null)
      .whereType<double>();

  final price2Stream = startStream
      .snapshot(
          price2State,
          (startFuel, price) => startFuel == Fuel.two
              ? Optional<double>.of(price)
              : Optional<double>.empty())
      .asOptional<double>()
      .mapWhereOptional();

  final price3Stream = startStream
      .snapshot(
          price3State,
          (startFuel, price) => startFuel == Fuel.three
              ? Optional<double>.of(price)
              : Optional<double>.empty())
      .asOptional<double>()
      .mapWhereOptional();

  return price1Stream.orElses([price2Stream, price3Stream]).toState(0);
}

class Fill {
  final ValueState<double> priceState;

  final ValueState<double> dollarsDeliveredState;

  final ValueState<double> litersDeliveredState;
  factory Fill({
    @required EventStream<Unit> clearAccumulatorStream,
    @required EventStream<int> fuelsPulsesStream,
    @required ValueState<double> calibrationState,
    @required ValueState<double> price1State,
    @required ValueState<double> price2State,
    @required ValueState<double> price3State,
    @required EventStream<Fuel> startStream,
  }) {
    final priceState =
        _capturePrice(startStream, price1State, price2State, price3State);

    final litersDeliveredState =
        accumulate(clearAccumulatorStream, fuelsPulsesStream, calibrationState);

    final dollarsDeliveredState = litersDeliveredState.combine(
        priceState, (price, litersDelivered) => price * litersDelivered);

    return Fill._(
        priceState: priceState,
        dollarsDeliveredState: dollarsDeliveredState,
        litersDeliveredState: litersDeliveredState);
  }
  Fill._(
      {this.priceState, this.dollarsDeliveredState, this.litersDeliveredState});
}
