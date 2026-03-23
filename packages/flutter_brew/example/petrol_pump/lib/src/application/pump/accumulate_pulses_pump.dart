import 'package:frappe/frappe.dart';

import '../../domain/logic/accumulate.dart';
import '../../domain/logic/lifecycle.dart';
import '../../domain/models.dart';
import '../../domain/port/pump.dart';

/// Chapter 2: Accumulates fuel pulses and shows liters delivered.
class AccumulatePulsesPump extends BasePump {
  /// Produces delivery mode and a quantity LCD showing accumulated liters.
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
