import 'package:frappe/frappe.dart';

import 'fill.dart';
import '../models.dart';

/// Manages preset dollar amount and controls delivery speed.
class Preset {
  /// The current delivery mode: which fuel at what speed, or off.
  final ValueState<Delivery> deliveryState;

  /// Whether the keypad is accepting input (disabled during slow delivery).
  final ValueState<bool> isKeypadActiveState;

  factory Preset({
    required Fill fill,
    required ValueState<int> presetDollarsState,
    required ValueState<Fuel?> fuelFlowingState,
  }) {
    final speedState = presetDollarsState.combine3(
        fill.priceState, fill.dollarsDeliveredState, fill.litersDeliveredState,
        (presetDollars, price, dollarsDelivered, litersDelivered) {
      if (presetDollars > 0) {
        if (dollarsDelivered >= presetDollars) {
          return _Speed.stopped;
        }
        // Switch to slow when within 0.1 liters of the preset target.
        final slowLitersThreshold = presetDollars / price - 0.1;
        return litersDelivered < slowLitersThreshold
            ? _Speed.fast
            : _Speed.slow;
      }
      return _Speed.fast;
    });

    final deliveryState =
        fuelFlowingState.combine(speedState, (fuelFlowing, speed) {
      if (fuelFlowing != null && speed != _Speed.stopped) {
        return switch (fuelFlowing) {
          Fuel.one => speed == _Speed.fast ? Delivery.fast1 : Delivery.slow1,
          Fuel.two => speed == _Speed.fast ? Delivery.fast2 : Delivery.slow2,
          Fuel.three => speed == _Speed.fast ? Delivery.fast3 : Delivery.slow3,
        };
      }
      return Delivery.off;
    });

    final isKeypadActiveState = fuelFlowingState.combine(speedState,
        (fuelFlowing, speed) => fuelFlowing == null || speed == _Speed.fast);

    return Preset._(
      deliveryState: deliveryState,
      isKeypadActiveState: isKeypadActiveState,
    );
  }

  Preset._({
    required this.deliveryState,
    required this.isKeypadActiveState,
  });
}

enum _Speed {
  /// Full delivery rate -- the default when no preset or far from target.
  fast,

  /// Reduced rate -- activated when nearing the preset dollar amount.
  slow,

  /// Delivery halted -- the preset dollar amount has been reached.
  stopped,
}
