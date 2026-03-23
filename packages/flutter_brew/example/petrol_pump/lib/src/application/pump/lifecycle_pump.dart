import '../../domain/logic/lifecycle.dart';
import '../../domain/models.dart';
import '../../domain/port/pump.dart';

/// Chapter 1: Basic lifecycle — shows which nozzle is active.
class LifecyclePump extends BasePump {
  /// Produces delivery mode and a sale-cost LCD showing the active nozzle number.
  @override
  Outputs create(Inputs inputs) {
    final lifecycle = Lifecycle(
      nozzle1Stream: inputs.nozzle1Stream,
      nozzle2Stream: inputs.nozzle2Stream,
      nozzle3Stream: inputs.nozzle3Stream,
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
      saleCostLcdState:
          lifecycle.fillActiveState.map<String>((fillActive) {
        if (fillActive != null) {
          return switch (fillActive) {
            Fuel.one => '1',
            Fuel.two => '2',
            Fuel.three => '3',
          };
        }
        return '';
      }),
    );
  }
}
