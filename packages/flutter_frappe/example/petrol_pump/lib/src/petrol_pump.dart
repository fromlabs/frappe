import 'package:frappe/frappe.dart';

import 'model.dart';

/// Function signature for creating pump [Outputs] from [Inputs].
///
/// Used as a lightweight alternative to subclassing [Pump] when only
/// a single function is needed.
typedef CreatePump = Outputs Function(Inputs inputs);

/// Abstract pump logic that transforms [Inputs] into [Outputs].
abstract class Pump {
  /// Builds the reactive output graph from the given [inputs].
  Outputs create(Inputs inputs);
}

/// A pump engine simulator that produces fuel pulses.
abstract class PumpEngineSimulator implements Disposable {
  /// Stream of fuel pulse counts emitted at a fixed tick rate.
  EventStream<int> get fuelPulsesStream;
}

/// A point-of-sale simulator that produces clear-sale events.
abstract class PosSimulator implements Disposable {
  /// Fires when the POS terminal has finished processing and clears the sale.
  EventStream<Unit> get clearSaleStream;
}

/// Base class for pump logic implementations.
abstract class BasePump implements Pump {
  @override
  String toString() => runtimeType.toString();
}
