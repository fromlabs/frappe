import 'package:frappe/frappe.dart';

import 'numeric_key.dart';
import 'up_down.dart';

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
