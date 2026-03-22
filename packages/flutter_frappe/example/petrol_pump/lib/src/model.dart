import 'package:frappe/frappe.dart';

/// Fuel delivery speed state.
enum Delivery { off, slow1, fast1, slow2, fast2, slow3, fast3 }

/// Fuel type selection.
enum Fuel { one, two, three }

/// Numeric keypad key.
enum NumericKey {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  clear,
}

/// Nozzle position.
enum UpDown { up, down }

/// Reactive inputs to the pump logic.
class Inputs {
  final EventStream<UpDown> nozzle1Stream;
  final EventStream<UpDown> nozzle2Stream;
  final EventStream<UpDown> nozzle3Stream;
  final EventStream<NumericKey> keypadStream;
  final EventStream<int> fuelPulsesStream;
  final ValueState<double> calibrationState;
  final ValueState<double> price1State;
  final ValueState<double> price2State;
  final ValueState<double> price3State;
  final EventStream<Unit> clearSaleStream;

  Inputs({
    required this.nozzle1Stream,
    required this.nozzle2Stream,
    required this.nozzle3Stream,
    required this.keypadStream,
    required this.fuelPulsesStream,
    required this.calibrationState,
    required this.price1State,
    required this.price2State,
    required this.price3State,
    required this.clearSaleStream,
  });

  /// Creates inputs with default (inert) streams and states.
  factory Inputs.defaults({
    EventStream<UpDown>? nozzle1Stream,
    EventStream<UpDown>? nozzle2Stream,
    EventStream<UpDown>? nozzle3Stream,
    EventStream<NumericKey>? keypadStream,
    EventStream<int>? fuelPulsesStream,
    ValueState<double>? calibrationState,
    ValueState<double>? price1State,
    ValueState<double>? price2State,
    ValueState<double>? price3State,
    EventStream<Unit>? clearSaleStream,
  }) {
    return Inputs(
      nozzle1Stream: nozzle1Stream ?? EventStream.never(),
      nozzle2Stream: nozzle2Stream ?? EventStream.never(),
      nozzle3Stream: nozzle3Stream ?? EventStream.never(),
      keypadStream: keypadStream ?? EventStream.never(),
      fuelPulsesStream: fuelPulsesStream ?? EventStream.never(),
      calibrationState: calibrationState ?? ValueState.constant(0),
      price1State: price1State ?? ValueState.constant(0),
      price2State: price2State ?? ValueState.constant(0),
      price3State: price3State ?? ValueState.constant(0),
      clearSaleStream: clearSaleStream ?? EventStream.never(),
    );
  }
}

/// Reactive outputs from the pump logic.
class Outputs {
  final ValueState<Delivery> deliveryState;
  final ValueState<String> presetLcdState;
  final ValueState<String> saleCostLcdState;
  final ValueState<String> saleQuantityLcdState;
  final ValueState<String> priceLcd1State;
  final ValueState<String> priceLcd2State;
  final ValueState<String> priceLcd3State;
  final EventStream<Unit> beepStream;
  final EventStream<Sale> saleCompleteStream;

  Outputs({
    required this.deliveryState,
    required this.presetLcdState,
    required this.saleCostLcdState,
    required this.saleQuantityLcdState,
    required this.priceLcd1State,
    required this.priceLcd2State,
    required this.priceLcd3State,
    required this.beepStream,
    required this.saleCompleteStream,
  });

  /// Creates outputs with default (inert) values.
  factory Outputs.defaults({
    ValueState<Delivery>? deliveryState,
    ValueState<String>? presetLcdState,
    ValueState<String>? saleCostLcdState,
    ValueState<String>? saleQuantityLcdState,
    ValueState<String>? priceLcd1State,
    ValueState<String>? priceLcd2State,
    ValueState<String>? priceLcd3State,
    EventStream<Unit>? beepStream,
    EventStream<Sale>? saleCompleteStream,
  }) {
    return Outputs(
      deliveryState: deliveryState ?? ValueState.constant(Delivery.off),
      presetLcdState: presetLcdState ?? ValueState.constant(''),
      saleCostLcdState: saleCostLcdState ?? ValueState.constant(''),
      saleQuantityLcdState: saleQuantityLcdState ?? ValueState.constant(''),
      priceLcd1State: priceLcd1State ?? ValueState.constant(''),
      priceLcd2State: priceLcd2State ?? ValueState.constant(''),
      priceLcd3State: priceLcd3State ?? ValueState.constant(''),
      beepStream: beepStream ?? EventStream.never(),
      saleCompleteStream: saleCompleteStream ?? EventStream.never(),
    );
  }
}

/// A completed fuel sale.
class Sale {
  final Fuel fuel;
  final double price;
  final double quantity;
  final double cost;

  const Sale({
    required this.fuel,
    required this.price,
    required this.quantity,
    required this.cost,
  });

  @override
  String toString() =>
      'Sale(fuel: $fuel, price: $price, quantity: $quantity, cost: $cost)';
}
