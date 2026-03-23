import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/lifecycle.dart';
import '../logic/notify_point_of_sale.dart';
import '../logic/price.dart';
import '../model.dart';
import '../petrol_pump.dart';

/// Chapter 4b: Full lifecycle with point-of-sale notification and clear-sale.
class ClearSalePump extends BasePump {
  /// Produces all display outputs plus sale-complete events and beep on clear.
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

    return Outputs.defaults(
      deliveryState:
          notifyPointOfSale.fuelFlowingState.map<Delivery>((fuelFlowing) {
        if (fuelFlowing != null) {
          return switch (fuelFlowing) {
            Fuel.one => Delivery.fast1,
            Fuel.two => Delivery.fast2,
            Fuel.three => Delivery.fast3,
          };
        }
        return Delivery.off;
      }),
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
      beepStream: notifyPointOfSale.beepStream,
      saleCompleteStream: notifyPointOfSale.saleCompleteStream,
    );
  }
}
