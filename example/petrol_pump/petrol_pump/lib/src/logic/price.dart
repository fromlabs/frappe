import 'package:frappe/frappe.dart';

import '../model.dart';

ValueState<String> priceLcd(
  OptionalValueState<Fuel> fillActiveState,
  ValueState<double> priceState,
  Fuel selectedFuel,
  Inputs inputs,
) {
  ValueState<double> idlePriceState;

  switch (selectedFuel) {
    case Fuel.one:
      idlePriceState = inputs.price1State;
      break;
    case Fuel.two:
      idlePriceState = inputs.price2State;
      break;
    case Fuel.three:
      idlePriceState = inputs.price3State;
      break;
  }

  return fillActiveState.combine2(priceState, idlePriceState,
      (fillActive, price, idlePrice) {
    if (fillActive.isPresent) {
      if (fillActive.value == selectedFuel) {
        return price.toString();
      } else {
        return '';
      }
    } else {
      return idlePrice.toString();
    }
  });
}
