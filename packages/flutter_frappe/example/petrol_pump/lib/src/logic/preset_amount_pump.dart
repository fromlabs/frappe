import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/keypad.dart';
import '../logic/lifecycle.dart';
import '../logic/notify_point_of_sale.dart';
import '../logic/preset.dart';
import '../logic/price.dart';
import '../model.dart';
import '../petrol_pump.dart';

/// Chapter 4c: Full pump with preset amount, keypad, and speed control.
class PresetAmountPump extends BasePump {
  /// Produces all display outputs with preset-controlled speed, keypad, beep, and sale events.
  @override
  Outputs create(Inputs inputs) {
    // Break the circular dependency: Fill needs startStream, but it comes
    // from NotifyPointOfSale which depends on Fill.
    final (_, (fill, notifyPointOfSale)) =
        EventStream.loopWith((EventStream<Fuel> startSelf) {
      final fill = Fill(
        clearAccumulatorStream: inputs.clearSaleStream,
        fuelsPulsesStream: inputs.fuelPulsesStream,
        calibrationState: inputs.calibrationState,
        price1State: inputs.price1State,
        price2State: inputs.price2State,
        price3State: inputs.price3State,
        startStream: startSelf,
      );

      final notifyPointOfSale = NotifyPointOfSale(
        lifecycle: Lifecycle(
          nozzle1Stream: inputs.nozzle1Stream,
          nozzle2Stream: inputs.nozzle2Stream,
          nozzle3Stream: inputs.nozzle3Stream,
        ),
        fill: fill,
        clearSaleStream: inputs.clearSaleStream,
      );

      return (notifyPointOfSale.startStream, (fill, notifyPointOfSale));
    });

    // Break the circular dependency: Keypad needs isKeypadActive, but it
    // comes from Preset which depends on Keypad.
    final (_, (keypad, preset)) =
        ValueState.loopWith((ValueState<bool> activeSelf) {
      final keypad = Keypad(
        keypadStream: inputs.keypadStream,
        clearStream: inputs.clearSaleStream,
        activeState: activeSelf,
      );

      final preset = Preset(
        fill: fill,
        presetDollarsState: keypad.valueState,
        fuelFlowingState: notifyPointOfSale.fuelFlowingState,
      );

      return (preset.isKeypadActiveState, (keypad, preset));
    });

    final beepStream = notifyPointOfSale.beepStream.orElse(keypad.beepStream);

    return Outputs.defaults(
      deliveryState: preset.deliveryState,
      saleQuantityLcdState:
          fill.litersDeliveredState.map((liters) => liters.toString()),
      saleCostLcdState:
          fill.dollarsDeliveredState.map((dollars) => dollars.toString()),
      priceLcd1State: priceLcd(notifyPointOfSale.fillActiveState,
          fill.priceState, Fuel.one, inputs),
      priceLcd2State: priceLcd(notifyPointOfSale.fillActiveState,
          fill.priceState, Fuel.two, inputs),
      priceLcd3State: priceLcd(notifyPointOfSale.fillActiveState,
          fill.priceState, Fuel.three, inputs),
      presetLcdState: keypad.valueState.map((value) => value.toString()),
      beepStream: beepStream,
      saleCompleteStream: notifyPointOfSale.saleCompleteStream,
    );
  }
}
