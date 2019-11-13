import 'package:meta/meta.dart';
import 'package:frappe/frappe.dart';
import '../logic/fill.dart';
import '../model.dart';

class Preset {
  final ValueState<Delivery> deliveryState;

  final ValueState<bool> isKeypadActiveState;

  factory Preset({
    @required Fill fill,
    @required ValueState<int> presetDollarsState,
    @required OptionalValueState<Fuel> fuelFlowingState,
  }) {
    final speedState = presetDollarsState.combine3(
        fill.priceState, fill.dollarsDeliveredState, fill.litersDeliveredState,
        (presetDollars, price, dollarsDelivered, litersDelivered) {
      if (presetDollars > 0) {
        if (dollarsDelivered >= presetDollars) {
          return _Speed.stopped;
        } else {
          final slowLitersThreshold = presetDollars / price - 0.1;

          if (litersDelivered < slowLitersThreshold) {
            return _Speed.fast;
          } else {
            return _Speed.slow;
          }
        }
      } else {
        return _Speed.fast;
      }
    });

    final deliveryState =
        fuelFlowingState.combine(speedState, (fuelFlowing, speed) {
      if (fuelFlowing.isPresent && speed != _Speed.stopped) {
        switch (fuelFlowing.value) {
          case Fuel.one:
            return speed == _Speed.fast ? Delivery.fast1 : Delivery.slow1;
          case Fuel.two:
            return speed == _Speed.fast ? Delivery.fast2 : Delivery.slow2;
          case Fuel.three:
            return speed == _Speed.fast ? Delivery.fast3 : Delivery.slow3;
          default:
            throw Error();
        }
      } else {
        return Delivery.off;
      }
    });

    final isKeypadActiveState = fuelFlowingState.combine(speedState,
        (fuelFlowing, speed) => !fuelFlowing.isPresent || speed == _Speed.fast);

    return Preset._(
      deliveryState: deliveryState,
      isKeypadActiveState: isKeypadActiveState,
    );
  }
  Preset._({
    this.deliveryState,
    this.isKeypadActiveState,
  });
}

enum _Speed { fast, slow, stopped }
