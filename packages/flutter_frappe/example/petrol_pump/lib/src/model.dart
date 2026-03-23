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
  /// Nozzle 1 up/down position changes.
  final EventStream<UpDown> nozzle1Stream;

  /// Nozzle 2 up/down position changes.
  final EventStream<UpDown> nozzle2Stream;

  /// Nozzle 3 up/down position changes.
  final EventStream<UpDown> nozzle3Stream;

  /// Key presses from the numeric keypad.
  final EventStream<NumericKey> keypadStream;

  /// Fuel pulses from the pump engine (each event carries a pulse count).
  final EventStream<int> fuelPulsesStream;

  /// Calibration factor converting pulses to fuel quantity.
  final ValueState<double> calibrationState;

  /// Current price per unit for fuel type 1.
  final ValueState<double> price1State;

  /// Current price per unit for fuel type 2.
  final ValueState<double> price2State;

  /// Current price per unit for fuel type 3.
  final ValueState<double> price3State;

  /// Signal from the POS terminal to clear the completed sale.
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

  /// References all reactive fields via [collector], keeping them alive
  /// until the collector is disposed. Returns `this` for chaining.
  Inputs hold(FrappeReferenceCollector collector) {
    collector
      ..add(nozzle1Stream)
      ..add(nozzle2Stream)
      ..add(nozzle3Stream)
      ..add(keypadStream)
      ..add(fuelPulsesStream)
      ..add(calibrationState)
      ..add(price1State)
      ..add(price2State)
      ..add(price3State)
      ..add(clearSaleStream);
    return this;
  }

  /// Creates inputs with default (inert) streams and states.
  ///
  /// Any parameter left null is replaced with a never-firing stream or a
  /// zero-valued constant state. Useful for partial overrides in tests or
  /// when only a subset of inputs is relevant.
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
  /// Current fuel delivery speed.
  final ValueState<Delivery> deliveryState;

  /// Text shown on the preset dollar amount LCD.
  final ValueState<String> presetLcdState;

  /// Text shown on the sale cost LCD.
  final ValueState<String> saleCostLcdState;

  /// Text shown on the sale quantity LCD.
  final ValueState<String> saleQuantityLcdState;

  /// Text shown on the fuel type 1 price LCD.
  final ValueState<String> priceLcd1State;

  /// Text shown on the fuel type 2 price LCD.
  final ValueState<String> priceLcd2State;

  /// Text shown on the fuel type 3 price LCD.
  final ValueState<String> priceLcd3State;

  /// Fires when the pump should emit a beep sound.
  final EventStream<Unit> beepStream;

  /// Fires with the completed [Sale] when fueling finishes.
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

  /// References all reactive fields via [collector], keeping them alive
  /// until the collector is disposed. Returns `this` for chaining.
  Outputs hold(FrappeReferenceCollector collector) {
    collector
      ..add(deliveryState)
      ..add(presetLcdState)
      ..add(saleCostLcdState)
      ..add(saleQuantityLcdState)
      ..add(priceLcd1State)
      ..add(priceLcd2State)
      ..add(priceLcd3State)
      ..add(beepStream)
      ..add(saleCompleteStream);
    return this;
  }

  /// Flattens a state-of-[Outputs] into a single [Outputs] by switch-mapping
  /// each field individually.
  ///
  /// [ValueState] fields use [switchMapState] + [distinct] so the output
  /// only updates when the inner value actually changes.
  /// [EventStream] fields use [switchMapStream] to forward events from
  /// whichever inner [Outputs] is currently active.
  factory Outputs.switchFrom(ValueState<Outputs> outputsState) {
    return Outputs(
      deliveryState: outputsState
          .switchMapState((o) => o.deliveryState)
          .distinct(),
      presetLcdState: outputsState
          .switchMapState((o) => o.presetLcdState)
          .distinct(),
      saleCostLcdState: outputsState
          .switchMapState((o) => o.saleCostLcdState)
          .distinct(),
      saleQuantityLcdState: outputsState
          .switchMapState((o) => o.saleQuantityLcdState)
          .distinct(),
      priceLcd1State: outputsState
          .switchMapState((o) => o.priceLcd1State)
          .distinct(),
      priceLcd2State: outputsState
          .switchMapState((o) => o.priceLcd2State)
          .distinct(),
      priceLcd3State: outputsState
          .switchMapState((o) => o.priceLcd3State)
          .distinct(),
      beepStream:
          outputsState.switchMapStream((o) => o.beepStream),
      saleCompleteStream:
          outputsState.switchMapStream((o) => o.saleCompleteStream),
    );
  }

  /// Creates outputs with default (inert) values.
  ///
  /// Any parameter left null is replaced with an off/empty constant state
  /// or a never-firing stream. Used as a fallback when no pump logic is
  /// selected.
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
  /// The type of fuel dispensed.
  final Fuel fuel;

  /// The per-unit price at which fuel was sold.
  final double price;

  /// The quantity of fuel dispensed (in liters).
  final double quantity;

  /// The total cost of the sale (price * quantity).
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
