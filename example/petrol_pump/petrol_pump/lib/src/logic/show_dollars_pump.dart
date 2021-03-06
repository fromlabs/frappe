import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/lifecycle.dart';
import '../logic/price.dart';
import '../model.dart';
import '../petrol_pump.dart';

class ShowDollarsPump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
    );

    final fill = Fill(
      clearAccumulatorStream: lifecycle.startStream.mapTo(unit),
      fuelsPulsesStream: inputs.fuelPulsesStream,
      calibrationState: inputs.calibrationState,
      price1State: inputs.price1State,
      price2State: inputs.price2State,
      price3State: inputs.price3State,
      startStream: lifecycle.startStream,
    );

    return Outputs.fromDefault(
      (builder) => builder
        ..deliveryState = lifecycle.fillActiveState.map<Delivery>((fillActive) {
          if (fillActive.isPresent) {
            switch (fillActive.value) {
              case Fuel.one:
                return Delivery.fast1;
              case Fuel.two:
                return Delivery.fast2;
              case Fuel.three:
                return Delivery.fast3;
              default:
                throw Error();
            }
          } else {
            return Delivery.off;
          }
        })
        ..saleQuantityLcdState =
            fill.litersDeliveredState.map((liters) => liters.toString())
        ..saleCostLcdState =
            fill.dollarsDeliveredState.map((dollars) => dollars.toString())
        ..priceLcd1State = priceLcd(
            lifecycle.fillActiveState, fill.priceState, Fuel.one, inputs)
        ..priceLcd2State = priceLcd(
            lifecycle.fillActiveState, fill.priceState, Fuel.two, inputs)
        ..priceLcd3State = priceLcd(
            lifecycle.fillActiveState, fill.priceState, Fuel.three, inputs),
    );
  }
}
