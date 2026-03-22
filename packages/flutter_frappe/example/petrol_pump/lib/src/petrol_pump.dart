import 'package:frappe/frappe.dart';

import 'model.dart';

/// Function signature for creating pump [Outputs] from [Inputs].
typedef CreatePump = Outputs Function(Inputs inputs);

/// Abstract pump logic that transforms [Inputs] into [Outputs].
abstract class Pump {
  Outputs create(Inputs inputs);
}

/// A pump engine simulator that produces fuel pulses.
abstract class PumpEngineSimulator implements Disposable {
  EventStream<int> get fuelPulsesStream;
}

/// A point-of-sale simulator that produces clear-sale events.
abstract class PosSimulator implements Disposable {
  EventStream<Unit> get clearSaleStream;
}

/// Base class for pump logic implementations.
abstract class BasePump implements Pump {
  @override
  String toString() => runtimeType.toString();
}
