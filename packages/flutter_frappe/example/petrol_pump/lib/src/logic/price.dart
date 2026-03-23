import 'package:frappe/frappe.dart';

import '../model.dart';

/// Computes the LCD price display for a given fuel nozzle.
///
/// Shows the active fill price when that fuel is flowing,
/// the idle price when no fuel is flowing, or blank when
/// a different fuel is active.
///
/// - [fillActiveState] indicates which fuel is currently being dispensed.
/// - [priceState] is the captured per-liter price for the active fill.
/// - [selectedFuel] is the fuel nozzle this LCD corresponds to.
/// - [inputs] provides the idle per-liter prices for each fuel.
ValueState<String> priceLcd(
  ValueState<Fuel?> fillActiveState,
  ValueState<double> priceState,
  Fuel selectedFuel,
  Inputs inputs,
) {
  final idlePriceState = switch (selectedFuel) {
    Fuel.one => inputs.price1State,
    Fuel.two => inputs.price2State,
    Fuel.three => inputs.price3State,
  };

  return fillActiveState.combine2(priceState, idlePriceState,
      (fillActive, price, idlePrice) {
    if (fillActive != null) {
      return fillActive == selectedFuel ? price.toString() : '';
    } else {
      return idlePrice.toString();
    }
  });
}
