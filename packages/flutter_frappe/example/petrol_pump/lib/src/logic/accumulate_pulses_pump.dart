import 'package:frappe/frappe.dart';

import '../logic/accumulate.dart';
import '../logic/lifecycle.dart';
import '../model.dart';
import '../petrol_pump.dart';

/// Chapter 2: Accumulates fuel pulses and shows liters delivered.
class AccumulatePulsesPump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
    );

    final litersDeliveredState = accumulate(
      lifecycle.startStream.mapToUnit(),
      inputs.fuelPulsesStream,
      inputs.calibrationState,
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
          litersDeliveredState.map((liters) => liters.toString()),
    );
  }
}
