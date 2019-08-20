import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/keypad.dart';
import '../logic/lifecycle.dart';
import '../logic/notify_point_of_sale.dart';
import '../logic/preset.dart';
import '../logic/price.dart';
import '../model.dart';
import '../petrol_pump.dart';

class PresetAmountPump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final startStreamRef = EventStreamReference<Fuel>();

    final fill = Fill(
      clearAccumulatorStream: inputs.clearSaleStream,
      fuelsPulsesStream: inputs.fuelPulsesStream,
      calibrationState: inputs.calibrationState,
      price1State: inputs.price1State,
      price2State: inputs.price2State,
      price3State: inputs.price3State,
      startStream: startStreamRef.stream,
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

    startStreamRef.link(notifyPointOfSale.startStream);

    final isKeypadActiveStateRef = ValueStateReference(true);

    final keypad = Keypad(
      keypadStream: inputs.keypadStream,
      clearStream: inputs.clearSaleStream,
      activeState: isKeypadActiveStateRef.state,
    );
/*
    final isFillActiveState = broadcastAsValueObservable(
        false, mapIsPresentOptional(notifyPointOfSale.fillActiveState));
*/
    final preset = Preset(
      fill: fill,
      presetDollarsState: keypad.valueState,
      fuelFlowingState: notifyPointOfSale.fuelFlowingState,
      // isFillActiveState: isFillActiveState,
    );

    isKeypadActiveStateRef.link(preset.isKeypadActiveState);

    final beepStream = notifyPointOfSale.beepStream.orElse(keypad.beepStream);

    return Outputs.fromDefault(
      (builder) => builder
        ..deliveryState = preset.deliveryState
        ..saleQuantityLcdState =
            fill.litersDeliveredState.map((liters) => liters.toString())
        ..saleCostLcdState =
            fill.dollarsDeliveredState.map((dollars) => dollars.toString())
        ..priceLcd1State = priceLcd(notifyPointOfSale.fillActiveState,
            fill.priceState, Fuel.one, inputs)
        ..priceLcd2State = priceLcd(notifyPointOfSale.fillActiveState,
            fill.priceState, Fuel.two, inputs)
        ..priceLcd3State = priceLcd(notifyPointOfSale.fillActiveState,
            fill.priceState, Fuel.three, inputs)
        ..presetLcdState = keypad.valueState.map((value) => value.toString())
        ..beepStream = beepStream
        ..saleCompleteStream = notifyPointOfSale.saleCompleteStream,
    );
  }
}
