import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/lifecycle.dart';
import '../logic/price.dart';
import '../model.dart';
import '../petrol_pump.dart';

/// Chapter 3: Shows dollars and liters delivered, plus per-nozzle prices.
class ShowDollarsPump extends BasePump {
  /// Produces delivery mode, liters/dollars LCDs, and per-nozzle price LCDs.
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
    );

    final fill = Fill(
      clearAccumulatorStream: lifecycle.startStream.mapToUnit(),
      fuelsPulsesStream: inputs.fuelPulsesStream,
      calibrationState: inputs.calibrationState,
      price1State: inputs.price1State,
      price2State: inputs.price2State,
      price3State: inputs.price3State,
      startStream: lifecycle.startStream,
    );

    return Outputs.defaults(
      deliveryState: lifecycle.fillActiveState.map<Delivery>((fillActive) {
        if (fillActive != null) {
          return switch (fillActive) {
            Fuel.one => Delivery.fast1,
            Fuel.two => Delivery.fast2,
            Fuel.three => Delivery.fast3,
          };
        }
        return Delivery.off;
      }),
      saleQuantityLcdState:
          fill.litersDeliveredState.map((liters) => liters.toString()),
      saleCostLcdState:
          fill.dollarsDeliveredState.map((dollars) => dollars.toString()),
      priceLcd1State: priceLcd(
          lifecycle.fillActiveState, fill.priceState, Fuel.one, inputs),
      priceLcd2State: priceLcd(
          lifecycle.fillActiveState, fill.priceState, Fuel.two, inputs),
      priceLcd3State: priceLcd(
          lifecycle.fillActiveState, fill.priceState, Fuel.three, inputs),
    );
  }
}
