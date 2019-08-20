import '../logic/lifecycle.dart';
import '../model.dart';
import '../petrol_pump.dart';

class LifecyclePump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
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
        ..saleCostLcdState =
            lifecycle.fillActiveState.map<String>((fillActive) {
          if (fillActive.isPresent) {
            switch (fillActive.value) {
              case Fuel.one:
                return '1';
              case Fuel.two:
                return '2';
              case Fuel.three:
                return '3';
              default:
                throw Error();
            }
          } else {
            return '';
          }
        }),
    );
  }
}
