import 'package:frappe/frappe.dart';

import '../logic/accumulate.dart';
import '../logic/lifecycle.dart';
import '../model.dart';
import '../petrol_pump.dart';

class AccumulatePulsesPump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
    );

    final litersDeliveredState = accumulate(
      lifecycle.startStream.mapTo(unit),
      inputs.fuelPulsesStream,
      inputs.calibrationState,
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
            litersDeliveredState.map((liters) => liters.toString()),
    );
  }
}
